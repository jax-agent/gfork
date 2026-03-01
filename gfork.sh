#!/usr/bin/env bash
# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Creates an isolated local clone of your repo so AI agents (or you)
# can work freely in sub-branches without touching the real repo.
# When done: push, pull, delete clone. Clean lifecycle.

gfork() {
  local feature="${1:?Usage: gfork <feature-name> [source-branch]}"
  local source_branch="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2
    return 1
  }
  local repo_name
  repo_name="$(basename "$repo_root")"
  local parent_dir
  parent_dir="$(dirname "$repo_root")"
  local dest="${parent_dir}/${repo_name}--${feature}"

  if [[ -d "$dest" ]]; then
    echo "✗ '$dest' already exists. Choose a different feature name or delete it first." >&2
    return 1
  fi

  echo "⎇  Cloning '$source_branch' → $dest"
  git clone --local "$repo_root" "$dest" -b "$source_branch" --quiet || return 1

  echo "✓ Clone ready: $dest"
  echo ""
  echo "  cd $(basename "$dest")"
  echo "  # Create feature branches freely — they merge back here"
  echo "  # When done: git push origin $source_branch → pull in original → rm -rf $dest"
}
