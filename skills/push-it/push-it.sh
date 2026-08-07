#!/usr/bin/env bash
# push-it: branch (if needed), push, open a GitHub PR, print its URL.
# Usage: push-it.sh [repo-dir]   (defaults to current directory)
set -euo pipefail

repo_dir="${1:-.}"
cd "$repo_dir"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "push-it: '$repo_dir' is not a git repository." >&2
  exit 1
fi

# --- Guard: dirty working tree -------------------------------------------
if [ -n "$(git status --porcelain)" ]; then
  echo "push-it: working tree has uncommitted changes. This skill moves existing" >&2
  echo "commits onto a branch and PRs them — it doesn't commit for you. Commit or" >&2
  echo "stash first, then say \"push it\" again." >&2
  exit 1
fi

# --- Guard: GitHub origin remote -----------------------------------------
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$origin_url" ]; then
  echo "push-it: no 'origin' remote configured in this repo." >&2
  exit 1
fi
case "$origin_url" in
  *github.com*) ;;
  *)
    echo "push-it: 'origin' ($origin_url) doesn't look like a GitHub remote — gh needs GitHub." >&2
    exit 1
    ;;
esac

# --- Guard: gh present & authenticated ------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "push-it: GitHub CLI ('gh') isn't installed. Install it with:" >&2
  echo "  winget install --id GitHub.cli" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "push-it: 'gh' isn't authenticated yet. Run this once:" >&2
  echo "  gh auth login" >&2
  exit 1
fi

# --- Determine base branch -------------------------------------------------
base="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)"
if [ -z "$base" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    base=main
  else
    base=master
  fi
fi

git fetch origin "$base" --quiet

current="$(git rev-parse --abbrev-ref HEAD)"
branch="$current"

# --- On base branch: create a feature branch and reset base back to origin -
if [ "$current" = "$base" ]; then
  ahead="$(git rev-list --count "origin/$base..HEAD")"
  if [ "$ahead" -eq 0 ]; then
    echo "push-it: nothing to push — $base has no commits ahead of origin/$base."
    exit 0
  fi

  subject="$(git log -1 --pretty=%s)"
  slug="$(echo "$subject" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40)"
  [ -z "$slug" ] && slug="update"
  branch="${slug}-$(date +%Y%m%d-%H%M%S)"

  git branch "$branch"
  git checkout "$branch"
  git branch -f "$base" "origin/$base"
  echo "push-it: created branch '$branch' from $base, reset local $base to origin/$base."
fi

# --- Push --------------------------------------------------------------
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push
else
  git push -u origin "$branch"
fi

# --- Reuse an existing open PR if there is one, else create one -----------
existing_url="$(gh pr list --head "$branch" --state open --json url -q '.[0].url' 2>/dev/null || true)"
if [ -n "$existing_url" ]; then
  echo "push-it: PR already open for '$branch':"
  echo "$existing_url"
  pr_url="$existing_url"
else
  gh pr create --fill --base "$base" --head "$branch" >/dev/null
  pr_url="$(gh pr view "$branch" --json url -q .url)"
  echo "push-it: opened PR for '$branch':"
  echo "$pr_url"
fi

# --- Open it in Chrome (best-effort — don't fail the run if this fails) ---
cmd.exe //c start chrome "$pr_url" >/dev/null 2>&1 || true
