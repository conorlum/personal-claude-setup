# statusline

Custom Claude Code status line. Shows, on one line:

- current directory
- git branch (if inside a repo)
- model name
- context window usage
- 5-hour usage window: used %, reset time, time until reset, and pace vs. a
  linear budget (`slow down` / `on pace` / `use more`)
- 7-day usage window: same, with reset shown as a date + time

Pace is `expected % used so far (linear over the window) − actual % used`.
Positive means under budget (green, "use more"), negative means over budget
(red, "slow down"), near zero is "on pace" (yellow).

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
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```
