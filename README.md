# personal-claude-setup

Personal Claude Code skills and misc files, for pulling onto a new machine.

## Setup

```bash
git clone https://github.com/conorlum/personal-claude-setup.git
cp -r personal-claude-setup/skills/* ~/.claude/skills/
```

See [statusline/README.md](statusline/README.md) to set up the custom status line.

## PowerShell profile

`powershell-profile/Microsoft.PowerShell_profile.ps1` has custom functions
(`code`, `matches`, `reps`, `stats`, `cswap`, `buildcats`). To use on a new Windows machine:

```powershell
copy powershell-profile\Microsoft.PowerShell_profile.ps1 $PROFILE
```

`buildcats` additionally requires the `CatBnB` repo cloned under
`~\Documents\GitHub`, `gh` authenticated, and Git Bash installed (it shells
out to `CatBnB\scripts\ship_playtest_build.sh`).
