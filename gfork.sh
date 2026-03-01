#!/usr/bin/env bash
# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Creates an isolated local clone of your repo so AI agents (or you)
# can work freely in sub-branches without touching the real repo.
# When done: push, pull, delete clone. Clean lifecycle.
#
# Usage:
#   gfork <feature-name> [source-branch]   — create a clone
#   gfork cd <feature-name>                — cd into an existing clone
#   gfork rm <feature-name>                — delete a clone (with confirmation)
#   gfork ls                               — list all clones for this repo

gfork() {
  # Subcommand routing
  case "${1:-}" in
    cd)
      _gfork_cd "${2:?Usage: gfork cd <feature-name>}"
      return
      ;;
    rm|remove|clean)
      _gfork_rm "${2:?Usage: gfork rm <feature-name>}"
      return
      ;;
    ls|list)
      _gfork_ls
      return
      ;;
    -h|--help|help)
      _gfork_help
      return
      ;;
  esac

  # Default: create a clone
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
  echo "  # When done: gfork rm $(basename "$dest" | sed "s/${repo_name}--//") or rm -rf $dest"
}

_gfork_dest() {
  # Given a feature name or full clone name, resolve the dest path
  local name="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2
    return 1
  }
  local repo_name parent_dir
  repo_name="$(basename "$repo_root")"
  parent_dir="$(dirname "$repo_root")"

  # Accept either "feature" or "repo--feature"
  if [[ "$name" == "${repo_name}--"* ]]; then
    echo "${parent_dir}/${name}"
  else
    echo "${parent_dir}/${repo_name}--${name}"
  fi
}

_gfork_cd() {
  local dest
  dest="$(_gfork_dest "$1")" || return 1

  if [[ ! -d "$dest" ]]; then
    echo "✗ Clone not found: $dest" >&2
    echo "  Run 'gfork ls' to see available clones." >&2
    return 1
  fi

  echo "→ $dest"
  cd "$dest" || return 1
}

_gfork_rm() {
  local dest
  dest="$(_gfork_dest "$1")" || return 1

  if [[ ! -d "$dest" ]]; then
    echo "✗ Clone not found: $dest" >&2
    echo "  Run 'gfork ls' to see available clones." >&2
    return 1
  fi

  # Check for uncommitted changes
  local dirty
  dirty="$(git -C "$dest" status --porcelain 2>/dev/null)"
  if [[ -n "$dirty" ]]; then
    echo "⚠  Clone has uncommitted changes:"
    git -C "$dest" status --short
    echo ""
  fi

  # Check for unpushed commits
  local unpushed
  unpushed="$(git -C "$dest" log --oneline @{u}.. 2>/dev/null)"
  if [[ -n "$unpushed" ]]; then
    echo "⚠  Clone has unpushed commits:"
    echo "$unpushed"
    echo ""
  fi

  read -r -p "Delete '$dest'? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Aborted."
    return 0
  fi

  rm -rf "$dest"
  echo "✓ Deleted: $dest"
}

_gfork_ls() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2
    return 1
  }
  local repo_name parent_dir
  repo_name="$(basename "$repo_root")"
  parent_dir="$(dirname "$repo_root")"

  local found=0
  for d in "${parent_dir}/${repo_name}--"*/; do
    [[ -d "$d" ]] || continue
    local feature="${d%/}"
    feature="${feature##*--}"
    echo "  $(basename "${d%/}")  (gfork cd $feature)"
    found=1
  done

  if [[ $found -eq 0 ]]; then
    echo "No clones found for '$repo_name'."
  fi
}

_gfork_help() {
  echo "gfork — isolated git clone workflow"
  echo ""
  echo "Usage:"
  echo "  gfork <feature-name> [branch]   Create a clone (default: current branch)"
  echo "  gfork cd <feature-name>         cd into an existing clone"
  echo "  gfork rm <feature-name>         Delete a clone (with confirmation)"
  echo "  gfork ls                        List clones for this repo"
  echo ""
  echo "Examples:"
  echo "  gfork auth-refactor             Create myrepo--auth-refactor/"
  echo "  gfork cd auth-refactor          Jump into it"
  echo "  gfork rm auth-refactor          Clean it up when done"
}
