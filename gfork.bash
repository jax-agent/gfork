# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Bash version. Installed to ~/.config/bash/functions/gfork.bash
# Loaded automatically if your .bashrc contains:
#   for f in ~/.config/bash/functions/*.bash; do source "$f"; done
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
    go)              shift; _gfork_go "$@";       return ;;
    -h|--help|help)  _gfork_help;    return ;;
  esac

  # Parse flags
  local use_local=0
  local branch_flag=""
  local args=()
  local skip_next=0
  for arg in "$@"; do
    if [[ "$skip_next" -eq 1 ]]; then
      branch_flag="$arg"
      skip_next=0
      continue
    fi
    case "$arg" in
      --local) use_local=1 ;;
      -b|--branch) skip_next=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "${args[@]}"

  local feature="${1:?Usage: gfork <feature-name> [-b branch] [--local]}"
  local source_branch="${branch_flag:-${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}}"
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

  # Full directory copy — preserves .env, dotfiles, gitignored local config
  # git clone only copies tracked files; rsync gives agents a ready-to-run sandbox
  echo "⎇  Copying '$source_branch' → $dest (including gitignored files)"
  rsync -a --quiet "$repo_root/" "$dest/" || return 1

  # Checkout the requested branch (rsync copies current HEAD state)
  local current_branch
  current_branch="$(git -C "$dest" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$current_branch" != "$source_branch" ]]; then
    git -C "$dest" checkout "$source_branch" --quiet 2>/dev/null || {
      echo "⚠  Branch '$source_branch' not found — staying on '$current_branch'" >&2
    }
  fi

  # Find the upstream remote URL from the parent repo
  local remote_url=""
  if [[ "$use_local" -eq 0 ]]; then
    for remote in origin upstream github; do
      local url
      url="$(git -C "$repo_root" remote get-url "$remote" 2>/dev/null)" || continue
      # Skip local paths
      if [[ "$url" == /* ]] || [[ "$url" == file://* ]] || [[ "$url" == ./* ]]; then
        continue
      fi
      remote_url="$url"
      break
    done
    # Fallback: any non-local remote
    if [[ -z "$remote_url" ]]; then
      while IFS= read -r remote; do
        local url
        url="$(git -C "$repo_root" remote get-url "$remote" 2>/dev/null)" || continue
        if [[ "$url" != /* ]] && [[ "$url" != file://* ]] && [[ "$url" != ./* ]]; then
          remote_url="$url"
          break
        fi
      done < <(git -C "$repo_root" remote)
    fi
    if [[ -n "$remote_url" ]]; then
      git -C "$dest" remote set-url origin "$remote_url"
      echo "   origin → $remote_url"
    else
      echo "⚠  No GitHub remote found — origin still points to local parent" >&2
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
  read -r -p "Delete '$dest'? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
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

  # If inside a repo, filter to that repo's clones; otherwise show all
  local repo_name=""
  if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    repo_name="$(basename "$repo_root")"
  fi

  local found=0
  for d in "$base"/*/; do
    [[ -d "$d" ]] || continue
    local base_name
    base_name="$(basename "${d%/}")"
    # Filter to current repo if inside one
    if [[ -n "$repo_name" && "$base_name" != "${repo_name}--"* ]]; then
      continue
    fi
    local feature="${base_name##*--}"
    echo "  $base_name  (gfork cd $feature)"
    found=1
  done

  if [[ $found -eq 0 ]]; then
    if [[ -n "$repo_name" ]]; then
      echo "No clones found for '$repo_name'. (All clones in $base)"
    else
      echo "No clones found in $base."
    fi
  fi
  return 0
}

_gfork_version_file() {
  echo "${GFORK_BASH_DIR:-$HOME/.config/bash/functions}/.gfork_version"
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
  local dest="${GFORK_BASH_DIR:-$HOME/.config/bash/functions}/gfork.bash"
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

  curl -fsSL "$base_url/gfork.bash" -o "$dest" || { echo "✗ Update failed." >&2; return 1; }
  [[ -n "$latest_sha" ]] && echo "$latest_sha" > "$vfile"

  # shellcheck disable=SC1090
  source "$dest"

  [[ -n "$latest_sha" ]] && echo "✓ Updated to $latest_sha" || echo "✓ Updated to latest"
  echo "  Reloaded in current shell."
}

_gfork_go() {
  # Parse flags (same as main gfork)
  local branch_flag="" args=() skip_next=0
  for arg in "$@"; do
    if [[ "$skip_next" -eq 1 ]]; then branch_flag="$arg"; skip_next=0; continue; fi
    case "$arg" in
      -b|--branch) skip_next=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "${args[@]}"

  local feature="${1:?Usage: gfork go <feature-name> [-b branch]}"

  # 1. Clone (reuse main gfork logic)
  local clone_args=("$feature")
  [[ -n "$branch_flag" ]] && clone_args+=("-b" "$branch_flag")
  gfork "${clone_args[@]}" || return 1

  # 2. Get destination path
  local dest
  dest="$(_gfork_dest "$feature")" || return 1

  # 3. Create a working branch feat/<name>
  local work_branch="feat/${feature}"
  git -C "$dest" checkout -b "$work_branch" --quiet 2>/dev/null || {
    # Branch name may be invalid — fall back to feature name as-is
    work_branch="$feature"
    git -C "$dest" checkout -b "$work_branch" --quiet 2>/dev/null || {
      echo "⚠  Could not create branch '$work_branch' — staying on $(git -C "$dest" rev-parse --abbrev-ref HEAD)" >&2
    }
  }
  echo "   branch → $(git -C "$dest" rev-parse --abbrev-ref HEAD)"

  # 4. CD into clone (affects current shell because this is a bash function)
  echo "→ $dest"
  cd "$dest" || return 1
}

_gfork_help() {
  echo "gfork — isolated git clone workflow"
  echo ""
  echo "Usage:"
  echo "  gfork go <feature-name> [-b branch]  Clone + create feat/<name> branch + cd in (one shot)"
  echo "  gfork <feature-name> [-b branch]     Clone only (full copy incl. .env)"
  echo "  gfork cd <feature-name>              cd into an existing clone"
  echo "  gfork rm <feature-name>              Delete a clone (with confirmation)"
  echo "  gfork ls                             List clones (current repo, or all)"
  echo "  gfork update                         Update gfork to the latest version"
  echo "  gfork update --force                 Reinstall even if already up to date"
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
