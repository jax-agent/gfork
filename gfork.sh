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
    update|upgrade)
      _gfork_update
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

_gfork_update() {
  local base_url="https://raw.githubusercontent.com/jax-agent/gfork/main"
  local api_url="https://api.github.com/repos/jax-agent/gfork/commits/main"

  echo "⟳  Checking for updates..."

  # Fetch latest commit SHA for display
  local latest_sha=""
  if command -v curl &>/dev/null; then
    latest_sha="$(curl -fsSL "$api_url" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/' | cut -c1-7)"
  fi

  # Detect shell and update the right file
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"
  if [[ -n "${FISH_VERSION:-}" ]]; then shell_name="fish"; fi
  if [[ -n "${NU_VERSION:-}" ]]; then shell_name="nu"; fi

  case "$shell_name" in
    fish)
      local dest="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions/gfork.fish"
      curl -fsSL "$base_url/gfork.fish" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
      ;;
    nu|nushell)
      local dest="${XDG_CONFIG_HOME:-$HOME/.config}/nushell/gfork.nu"
      curl -fsSL "$base_url/gfork.nu" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
      ;;
    *)
      # bash / zsh — update the sourced file and reload
      local dest="${HOME}/.gfork.sh"
      if [[ ! -f "$dest" ]]; then
        # Might be sourced from a custom path; update the running script itself
        dest="${BASH_SOURCE[0]:-${(%):-%x}}"
      fi
      curl -fsSL "$base_url/gfork.sh" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
      # Reload into current shell
      # shellcheck disable=SC1090
      source "$dest"
      ;;
  esac

  if [[ -n "$latest_sha" ]]; then
    echo "✓ Updated to $latest_sha"
  else
    echo "✓ Updated to latest"
  fi
  echo "  Restart your shell or open a new tab to pick up any new subcommands."
}

_gfork_help() {
  echo "gfork — isolated git clone workflow"
  echo ""
  echo "Usage:"
  echo "  gfork <feature-name> [branch]   Create a clone (default: current branch)"
  echo "  gfork cd <feature-name>         cd into an existing clone"
  echo "  gfork rm <feature-name>         Delete a clone (with confirmation)"
  echo "  gfork ls                        List clones for this repo"
  echo "  gfork update                    Update gfork to the latest version"
  echo ""
  echo "Examples:"
  echo "  gfork auth-refactor             Create myrepo--auth-refactor/"
  echo "  gfork cd auth-refactor          Jump into it"
  echo "  gfork rm auth-refactor          Clean it up when done"
  echo "  gfork update                    Pull latest from GitHub"
}
