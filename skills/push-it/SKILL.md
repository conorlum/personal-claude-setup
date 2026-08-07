---
name: push-it
description: Use when the user says "push it" (or close variants like "ship it", "PR this", "open a PR for this") after making local git commits, in a repo with a GitHub origin remote.
---

# Push It

## Overview
Turns "push it" into: branch off (if still on master/main), push, open a GitHub PR, hand back the link. All the git/gh mechanics live in `push-it.sh` so the behavior is deterministic — run the script rather than re-deriving the steps by hand.

## When to use
- User says "push it" / "ship it" / "PR this" after commits already exist locally.
- Repo has a GitHub `origin` remote.
- NOT for uncommitted changes — this skill moves existing commits, it doesn't create them. If the working tree is dirty, commit (or ask the user whether to commit) first.

## How to run
```
bash ~/.claude/skills/push-it/push-it.sh          # current directory
bash ~/.claude/skills/push-it/push-it.sh /path/to/repo
```
The script's last stdout line on success is the PR URL — read that back to the user verbatim, don't guess or reconstruct a link yourself.

## What it does
1. Aborts if the working tree is dirty.
2. Aborts if `origin` isn't a GitHub remote, or `gh` isn't installed/authenticated — prints the exact fix command in each case.
3. Detects the base branch (`origin/HEAD`, falling back to `main` then `master`).
4. If currently **on** the base branch with commits ahead of `origin/<base>`: creates a new branch at HEAD (named from the latest commit subject + timestamp), checks it out, then moves the local base-branch pointer back to `origin/<base>`. No `reset --hard`, no force-push — the base branch is simply not checked out anymore when its pointer moves, so the working tree is never touched.
5. If already on a **non-base** branch: skips branch creation — "if not done" is already done.
6. Pushes (`-u` on first push, plain `git push` afterward — never force-pushed).
7. Reuses an existing open PR for that branch if one exists; otherwise creates one with `gh pr create --fill`.
8. Prints the PR URL and opens it in a new Chrome tab (`cmd.exe /c start chrome <url>`, best-effort — a missing/renamed Chrome won't fail the run).

## Prerequisites
- `gh` installed and authenticated (`gh auth login` — interactive, one-time, the user has to run it themselves).
- Repo has a GitHub `origin` remote.

## Common mistakes
- Expecting it to commit uncommitted changes — it won't; it only moves commits that already exist.
- Worrying it might overwrite a branch with existing history — it never force-pushes; a diverged push fails loudly instead of silently clobbering anything.
