# statusline

Custom Claude Code status line. Shows:

- current directory
- git branch (if inside a repo)
- model name
- context window usage
- account email (from `~/.claude.json`'s `oauthAccount.emailAddress`), in
  pink — useful for telling two Claude accounts apart at a glance
- 5-hour usage window: used %, reset time, time until reset, and pace vs. a
  linear budget (`slow down` / `on pace` / `use more`), in bright blue/pace
  colors
- 7-day usage window: same, with reset shown as a date + time

Fields are packed onto as few lines as fit the terminal width (Claude Code
sets `$COLUMNS` before running the script) — a field that doesn't fit wraps
to a new line instead of running off the side.

Pace is `expected % used so far (linear over the window) − actual % used`.
Positive means under budget (bright green, "use more"), negative means over
budget (bright red, "slow down"), within ±4 points of zero is "on pace"
(bright yellow).

The 5h/7d segments only render once Claude Code's status line payload
includes `rate_limits.five_hour` / `rate_limits.seven_day` — that's only
populated for Claude.ai subscription accounts, and only after at least one
API response in the session. Without it, the line just shows directory /
branch / model / context.

## Requirements

- `bash` (Git Bash on Windows)
- `node` on PATH (used for JSON parsing instead of `jq`, which isn't
  installed by default on Windows)
- `git` on PATH (for the branch segment)

## Setup

```bash
cp statusline/statusline-command.sh ~/.claude/statusline-command.sh
```

Then add this to `~/.claude/settings.json` (merge with existing keys, don't
overwrite the file):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```

`refreshInterval` (seconds) makes Claude Code re-run the command on a timer,
in addition to its normal event-driven updates (new assistant message,
`/compact`, permission-mode change, etc.). Without it, the countdown/pace
fields here can go stale while you're idle, since nothing else triggers a
re-render. 30s keeps them reasonably fresh without spawning a `bash`+`node`
process every second for no real gain — the fields only display to the
minute anyway.
