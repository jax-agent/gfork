# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Zsh version. Installed to ~/.config/zsh/functions/gfork.zsh
# Loaded automatically if your .zshrc contains:
#   for f in ~/.config/zsh/functions/*.zsh; source $f
#
# Environment:
#   GFORK_DIR   Base directory for all clones (default: ~/.gfork)

_gfork_base() {
  echo "${GFORK_DIR:-$HOME/.gfork}"
}

gfork() {
  case "${1:-}" in
    cd)     _gfork_cd "${2:?Usage: gfork cd <feature-name>}";          return ;;
    rm|remove|clean) _gfork_rm "${2:?Usage: gfork rm <feature-name>}"; return ;;
    ls|list)         _gfork_ls;      return ;;
    update|upgrade)  shift; _gfork_update "$@";  return ;;
    -h|--help|help)  _gfork_help;    return ;;
  esac

  local feature="${1:?Usage: gfork <feature-name> [source-branch]}"
  # Parse flags
  local use_local=0
  local args=()
  for arg in "$@"; do
    case "$arg" in
      --local) use_local=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "${args[@]}"

  local source_branch="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ Not inside a git repository." >&2; return 1
  }
  local repo_name base dest
  repo_name="$(basename "$repo_root")"
  base="$(_gfork_base)"
  dest="${base}/${repo_name}--${feature}"

  if [[ -d "$dest" ]]; then
    echo "✗ '$dest' already exists. Choose a different feature name or delete it first." >&2
    return 1
  fi

  # Resolve clone source: prefer GitHub remote over local path
  local clone_src
  if [[ "$use_local" -eq 1 ]]; then
    clone_src="$repo_root"
    echo "⎇  Cloning locally from '$repo_root' ($source_branch) → $dest"
    git clone --local "$clone_src" "$dest" -b "$source_branch" --quiet || return 1
  else
    local remote_url=""
    for remote in origin upstream github; do
      local url
      url="$(git remote get-url "$remote" 2>/dev/null)" || continue
      if [[ "$url" == /* ]] || [[ "$url" == file://* ]] || [[ "$url" == ./* ]]; then
        continue
      fi
      remote_url="$url"
      break
    done
    if [[ -z "$remote_url" ]]; then
      while IFS= read -r remote; do
        local url
        url="$(git remote get-url "$remote" 2>/dev/null)" || continue
        if [[ "$url" != /* ]] && [[ "$url" != file://* ]] && [[ "$url" != ./* ]]; then
          remote_url="$url"
          break
        fi
      done < <(git remote)
    fi
    if [[ -n "$remote_url" ]]; then
      echo "⎇  Cloning from '$remote_url' ($source_branch) → $dest"
      git clone "$remote_url" "$dest" -b "$source_branch" --quiet || return 1
    else
      echo "⚠  No remote URL found; falling back to local clone (push may not reach GitHub)" >&2
      echo "⎇  Cloning locally from '$repo_root' ($source_branch) → $dest"
      git clone --local "$repo_root" "$dest" -b "$source_branch" --quiet || return 1
    fi
  fi
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
  local repo_name base
  repo_name="$(basename "$repo_root")"
  base="$(_gfork_base)"

  if [[ "$name" == "${repo_name}--"* ]]; then
    echo "${base}/${name}"
  else
    echo "${base}/${repo_name}--${name}"
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
  read "confirm?Delete '$dest'? [y/N] "
  if [[ "${confirm:l}" != "y" ]]; then
    echo "Aborted."; return 0
  fi
  rm -rf "$dest"
  echo "✓ Deleted: $dest"
}

_gfork_ls() {
  local base
  base="$(_gfork_base)"

  if [[ ! -d "$base" ]]; then
    echo "No clones yet. Run 'gfork <feature-name>' to create one."
    return 0
  fi

  local repo_name=""
  local repo_root
  if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    repo_name="$(basename "$repo_root")"
  fi

  local found=0
  for d in "$base"/*/; do
    [[ -d "$d" ]] || continue
    local base_name="${${d%/}##*/}"
    if [[ -n "$repo_name" && "$base_name" != "${repo_name}--"* ]]; then
      continue
    fi
    local feature="${base_name##*--}"
    echo "  $base_name  (gfork cd $feature)"
    found=1
  done

  if (( !found )); then
    if [[ -n "$repo_name" ]]; then
      echo "No clones found for '$repo_name'. (All clones in $base)"
    else
      echo "No clones found in $base."
    fi
  fi
  return 0
}

_gfork_version_file() {
  echo "${GFORK_ZSH_DIR:-$HOME/.config/zsh/functions}/.gfork_version"
}

_gfork_local_sha() {
  local vfile
  vfile="$(_gfork_version_file)"
  [[ -f "$vfile" ]] && cat "$vfile" || echo ""
}

_gfork_update() {
  local force=0
  for arg in "$@"; do
    [[ "$arg" == "--force" || "$arg" == "-f" ]] && force=1
  done

  local base_url="https://raw.githubusercontent.com/jax-agent/gfork/main"
  local api_url="https://api.github.com/repos/jax-agent/gfork/commits/main"
  local dest="${GFORK_ZSH_DIR:-$HOME/.config/zsh/functions}/gfork.zsh"
  local vfile
  vfile="$(_gfork_version_file)"

  echo "⟳  Checking for updates..."

  local latest_sha local_sha
  latest_sha="$(curl -fsSL "$api_url" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/' | cut -c1-7)"
  local_sha="$(_gfork_local_sha)"

  if [[ -n "$latest_sha" && "$latest_sha" == "$local_sha" && $force -eq 0 ]]; then
    echo "✓ Already up to date ($latest_sha)"
    echo "  Use 'gfork update --force' to reinstall anyway."
    return 0
  fi

  [[ $force -eq 1 && "$latest_sha" == "$local_sha" ]] && echo "  Forcing reinstall of $latest_sha..."

  curl -fsSL "$base_url/gfork.zsh" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
  [[ -n "$latest_sha" ]] && echo "$latest_sha" > "$vfile"
  source "$dest"

  [[ -n "$latest_sha" ]] && echo "✓ Updated to $latest_sha" || echo "✓ Updated to latest"
  echo "  Reloaded in current shell."
}

_gfork_help() {
  echo "gfork — isolated git clone workflow"
  echo ""
  echo "Usage:"
  echo "  gfork <feature-name> [branch] [--local]   Fork from GitHub remote (default) or local with --local"
  echo "  gfork cd <feature-name>         cd into an existing clone"
  echo "  gfork rm <feature-name>         Delete a clone (with confirmation)"
  echo "  gfork ls                        List clones (current repo, or all)"
  echo "  gfork update                    Update gfork to the latest version"
  echo "  gfork update --force            Reinstall even if already up to date"
  echo ""
  echo "Clones are stored in: ${GFORK_DIR:-$HOME/.gfork}"
  echo "Override with: export GFORK_DIR=/your/path"
  echo ""
  echo "Examples:"
  echo "  gfork auth-refactor             Create ~/.gfork/myrepo--auth-refactor"
  echo "  gfork cd auth-refactor          Jump into it"
  echo "  gfork rm auth-refactor          Clean it up when done"
  echo "  gfork update                    Pull latest from GitHub"
}
