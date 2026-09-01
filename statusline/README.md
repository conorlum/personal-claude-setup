# statusline

Custom Claude Code status line. Shows:

- current directory
- git branch (if inside a repo)
- model name and effort level (e.g. `Sonnet 5 high`)
- context window usage
- account email (from `~/.claude.json`'s `oauthAccount.emailAddress`), in
  pink — useful for telling two Claude accounts apart at a glance
- 5-hour usage window for the active account: used %, reset time, time until
  reset, and pace vs. a linear budget (`slow down` / `on pace` / `use more`),
  in bright blue/pace colors
- 5-hour usage window, labeled `5h(all)`: same, but pooled across every
  account `cswap` knows about rather than just the active one — mean used %,
  mean expected %, reset shown as the soonest of the accounts' reset dates.
  (Weekly usage isn't shown here — check it with `cswap list`, which prints
  its own combined 7d row.)

Fields are packed onto as few lines as fit the terminal width (Claude Code
sets `$COLUMNS` before running the script) — a field that doesn't fit wraps
to a new line instead of running off the side.

Pace is `expected % used so far (linear over the window) − actual % used`.
Positive means under budget (bright green, "use more"), negative means over
budget (bright red, "slow down"), within ±4 points of zero is "on pace"
(bright yellow).

The first 5h segment only renders once Claude Code's status line payload
includes `rate_limits.five_hour` — that's only populated for Claude.ai
subscription accounts, and only after at least one API response in the
session. The 5h(all) segment instead comes from `cswap.exe list --json`, so
it renders whenever `cswap` has at least one account with 5-hour usage data,
independent of the current session's rate-limit payload. Without either, the
line just shows directory / branch / model / context.

## Requirements

- `bash` (Git Bash on Windows)
- `node` on PATH (used for JSON parsing instead of `jq`, which isn't
  installed by default on Windows)
- `git` on PATH (for the branch segment)
- `cswap.exe` on PATH (for the combined 5h(all) segment) — the 5h(all)
  segment just renders blank if it's missing or errors

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
