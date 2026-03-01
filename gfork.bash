# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Bash version. Installed to ~/.config/bash/functions/gfork.bash
# Loaded automatically if your .bashrc contains:
#   for f in ~/.config/bash/functions/*.bash; do source "$f"; done

gfork() {
  case "${1:-}" in
    cd)     _gfork_cd "${2:?Usage: gfork cd <feature-name>}";  return ;;
    rm|remove|clean) _gfork_rm "${2:?Usage: gfork rm <feature-name>}"; return ;;
    ls|list)         _gfork_ls;      return ;;
    update|upgrade)  _gfork_update;  return ;;
    -h|--help|help)  _gfork_help;    return ;;
  esac

  local feature="${1:?Usage: gfork <feature-name> [source-branch]}"
  local source_branch="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2; return 1
  }
  local repo_name parent_dir dest
  repo_name="$(basename "$repo_root")"
  parent_dir="$(dirname "$repo_root")"
  dest="${parent_dir}/${repo_name}--${feature}"

  if [[ -d "$dest" ]]; then
    echo "✗ '$dest' already exists. Choose a different feature name or delete it first." >&2
    return 1
  fi

  echo "⎇  Cloning '$source_branch' → $dest"
  git clone --local "$repo_root" "$dest" -b "$source_branch" --quiet || return 1
  echo "✓ Clone ready: $dest"
  echo ""
  echo "  gfork cd $feature"
  echo "  # When done: gfork rm $feature"
}

_gfork_dest() {
  local name="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2; return 1
  }
  local repo_name parent_dir
  repo_name="$(basename "$repo_root")"
  parent_dir="$(dirname "$repo_root")"
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

  local dirty unpushed
  dirty="$(git -C "$dest" status --porcelain 2>/dev/null)"
  if [[ -n "$dirty" ]]; then
    echo "⚠  Clone has uncommitted changes:"
    git -C "$dest" status --short
    echo ""
  fi
  unpushed="$(git -C "$dest" log --oneline @{u}.. 2>/dev/null)"
  if [[ -n "$unpushed" ]]; then
    echo "⚠  Clone has unpushed commits:"
    echo "$unpushed"
    echo ""
  fi

  local confirm
  read -r -p "Delete '$dest'? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Aborted."; return 0
  fi
  rm -rf "$dest"
  echo "✓ Deleted: $dest"
}

_gfork_ls() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2; return 1
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
  [[ $found -eq 0 ]] && echo "No clones found for '$repo_name'."
  return 0
}

_gfork_update() {
  local base_url="https://raw.githubusercontent.com/jax-agent/gfork/main"
  local api_url="https://api.github.com/repos/jax-agent/gfork/commits/main"
  local dest="${GFORK_BASH_DIR:-$HOME/.config/bash/functions}/gfork.bash"

  echo "⟳  Checking for updates..."
  local latest_sha=""
  latest_sha="$(curl -fsSL "$api_url" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/' | cut -c1-7)"

  curl -fsSL "$base_url/gfork.bash" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
  # shellcheck disable=SC1090
  source "$dest"

  [[ -n "$latest_sha" ]] && echo "✓ Updated to $latest_sha" || echo "✓ Updated to latest"
  echo "  Reloaded in current shell."
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
