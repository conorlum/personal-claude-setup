#!/usr/bin/env bash
# Claude Code status line
# Line 1: directory | git branch | model | context usage
# Line 2/3: 5h and 7d usage windows, with pace vs. a linear budget

input=$(cat)

fields=$(printf '%s' "$input" | node -e '
let raw = "";
process.stdin.on("data", d => raw += d);
process.stdin.on("end", () => {
  let j;
  try { j = JSON.parse(raw); } catch (e) { j = {}; }
  const g = (o, p, d) => p.split(".").reduce((a, k) => (a && a[k] !== undefined ? a[k] : undefined), o) ?? d ?? "";

  const now = Date.now() / 1000;

  function fmtDuration(sec) {
    sec = Math.max(0, Math.round(sec));
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  }

  function fmtClock(ts) {
    return new Date(ts * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
  }

  function fmtDate(ts) {
    const dt = new Date(ts * 1000);
    const month = dt.toLocaleString([], { month: "short" });
    return `${month} ${dt.getDate()} ${fmtClock(ts)}`;
  }

  function window(usedPct, resetsAt, windowSec, resetFmt) {
    if (usedPct === "" || resetsAt === "") return ["", "", "", "", ""];
    usedPct = Number(usedPct);
    resetsAt = Number(resetsAt);
    const windowStart = resetsAt - windowSec;
    const elapsed = Math.min(Math.max(now - windowStart, 0), windowSec);
    const expectedPct = (elapsed / windowSec) * 100;
    const pace = expectedPct - usedPct; // + = under budget, - = over budget
    const verdict = Math.abs(pace) < 2 ? "on pace" : pace > 0 ? "use more" : "slow down";
    const paceStr = (pace >= 0 ? "+" : "") + pace.toFixed(1);
    return [
      usedPct.toFixed(0),
      resetFmt(resetsAt),
      fmtDuration(resetsAt - now),
      paceStr,
      verdict,
    ];
  }

  const five = window(g(j, "rate_limits.five_hour.used_percentage", ""), g(j, "rate_limits.five_hour.resets_at", ""), 5 * 3600, fmtClock);
  const week = window(g(j, "rate_limits.seven_day.used_percentage", ""), g(j, "rate_limits.seven_day.resets_at", ""), 7 * 86400, fmtDate);

  const out = [
    g(j, "workspace.current_dir"),
    g(j, "model.display_name"),
    g(j, "context_window.used_percentage"),
    ...five,
    ...week,
  ];
  process.stdout.write(out.join("\t"));
});
')

IFS=$'\t' read -r dir model used_ctx \
  five_used five_reset five_in five_pace five_verdict \
  week_used week_reset week_in week_pace week_verdict <<< "$fields"

dir_display=$(basename "$dir")

branch=""
if git -C "$dir" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
fi

ctx_str=""
if [ -n "$used_ctx" ]; then
  ctx_str=$(printf 'Context %.0f%%' "$used_ctx")
fi

CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
BLUE='\033[34m'
GRAY='\033[90m'
RED='\033[31m'
RESET='\033[0m'

verdict_color() {
  case "$1" in
    "slow down") echo "$RED" ;;
    "use more") echo "$GREEN" ;;
    *) echo "$YELLOW" ;;
  esac
}

# --- line 1 ---
line1="$(printf '%b%s%b' "$CYAN" "$dir_display" "$RESET")"

if [ -n "$branch" ]; then
  line1="$line1 $(printf '%b|%b' "$GRAY" "$RESET") $(printf '%b(%s)%b' "$GREEN" "$branch" "$RESET")"
fi

line1="$line1 $(printf '%b|%b' "$GRAY" "$RESET") $(printf '%b%s%b' "$MAGENTA" "$model" "$RESET")"

if [ -n "$ctx_str" ]; then
  line1="$line1 $(printf '%b|%b' "$GRAY" "$RESET") $(printf '%b%s%b' "$YELLOW" "$ctx_str" "$RESET")"
fi

# --- usage windows, appended to the same line ---
out="$line1"

fmt_window() {
  local label="$1" used="$2" reset="$3" in="$4" pace="$5" verdict="$6"
  local pcolor
  pcolor=$(verdict_color "$verdict")
  printf '%b%s:%b %s%%  resets %s  in %s  pace: %b%s%%%b (%s)' \
    "$BLUE" "$label" "$RESET" \
    "$used" "$reset" "$in" \
    "$pcolor" "$pace" "$RESET" \
    "$verdict"
}

if [ -n "$five_used" ]; then
  out="$out $(printf '%b|%b' "$GRAY" "$RESET") $(fmt_window "5h" "$five_used" "$five_reset" "$five_in" "$five_pace" "$five_verdict")"
fi

if [ -n "$week_used" ]; then
  out="$out $(printf '%b|%b' "$GRAY" "$RESET") $(fmt_window "7d" "$week_used" "$week_reset" "$week_in" "$week_pace" "$week_verdict")"
fi

printf '%s\n' "$out"
