#!/usr/bin/env bash
# Claude Code status line
# Fields: directory | git branch | model | context usage | account email |
# 5h usage window | 7d usage window (each with pace vs. a linear budget).
# Fields are packed onto as few lines as fit $COLUMNS, wrapping to a new
# line instead of running off the side.

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
    const verdict = Math.abs(pace) < 4 ? "on pace" : pace > 0 ? "use more" : "slow down";
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

account_email=$(node -e '
try {
  const j = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude.json", "utf8"));
  process.stdout.write((j.oauthAccount && j.oauthAccount.emailAddress) || "");
} catch (e) {}
' 2>/dev/null)

CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
BLUE='\033[94m'
GRAY='\033[90m'
RED='\033[31m'
PINK='\033[38;2;255;105;180m'
RESET='\033[0m'

verdict_color() {
  case "$1" in
    "slow down") echo '\033[91m' ;;
    "use more") echo '\033[92m' ;;
    *) echo '\033[93m' ;;
  esac
}

fmt_window() {
  local label="$1" used="$2" reset="$3" in="$4" pace="$5" verdict="$6"
  local pcolor
  pcolor=$(verdict_color "$verdict")
  printf '%b%s: %s%%  resets %s  in %s%b  pace: %b%s%% (%s)%b' \
    "$BLUE" "$label" "$used" "$reset" "$in" "$RESET" \
    "$pcolor" "$pace" "$verdict" "$RESET"
}

# --- build one "atom" per logical field, then pack atoms onto lines that fit
# the terminal width (Claude Code sets COLUMNS before running this script),
# wrapping to a new row instead of letting a line run off the side. ---

strip_ansi() {
  printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g'
}

visible_len() {
  local s
  s=$(strip_ansi "$1")
  printf '%s' "${#s}"
}

dir_atom="$(printf '%b%s%b' "$CYAN" "$dir_display" "$RESET")"
model_atom="$(printf '%b%s%b' "$MAGENTA" "$model" "$RESET")"

branch_atom=""
[ -n "$branch" ] && branch_atom="$(printf '%b(%s)%b' "$GREEN" "$branch" "$RESET")"

ctx_atom=""
[ -n "$ctx_str" ] && ctx_atom="$(printf '%b%s%b' "$YELLOW" "$ctx_str" "$RESET")"

account_atom=""
[ -n "$account_email" ] && account_atom="$(printf '%b%s%b' "$PINK" "$account_email" "$RESET")"

five_atom=""
[ -n "$five_used" ] && five_atom="$(fmt_window "5h" "$five_used" "$five_reset" "$five_in" "$five_pace" "$five_verdict")"

week_atom=""
[ -n "$week_used" ] && week_atom="$(fmt_window "7d" "$week_used" "$week_reset" "$week_in" "$week_pace" "$week_verdict")"

pipe_sep="$(printf '%b|%b' "$GRAY" "$RESET")"
cols="${COLUMNS:-80}"

lines=()
current=""
current_len=0

add_atom() {
  local atom="$1" alen needed
  [ -z "$atom" ] && return
  alen=$(visible_len "$atom")
  if [ -z "$current" ]; then
    current="$atom"
    current_len="$alen"
    return
  fi
  needed=$((current_len + 3 + alen))
  if [ "$needed" -le "$cols" ]; then
    current="$current $pipe_sep $atom"
    current_len="$needed"
  else
    lines+=("$current")
    current="$atom"
    current_len="$alen"
  fi
}

add_atom "$dir_atom"
add_atom "$branch_atom"
add_atom "$model_atom"
add_atom "$ctx_atom"
add_atom "$account_atom"
add_atom "$five_atom"
add_atom "$week_atom"

[ -n "$current" ] && lines+=("$current")

printf '%s\n' "${lines[@]}"
