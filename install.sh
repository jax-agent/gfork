#!/usr/bin/env bash
# gfork installer — auto-detects your shell
# https://github.com/jax-agent/gfork
set -e

BASE_URL="https://raw.githubusercontent.com/jax-agent/gfork/main"

detect_shell() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"
  if [[ -n "${FISH_VERSION:-}" ]]; then shell_name="fish"; fi
  if [[ -n "${NU_VERSION:-}" ]]; then shell_name="nu"; fi
  echo "$shell_name"
}

# Add a single line to a rc file only if it isn't already there
add_line_if_missing() {
  local file="$1" line="$2"
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
    echo "  → Added to $file"
  else
    echo "  → Already in $file (skipped)"
  fi
}

install_zsh() {
  local dir="${GFORK_ZSH_DIR:-$HOME/.config/zsh/functions}"
  local dest="$dir/gfork.zsh"
  local rc="$HOME/.zshrc"
  local loader='for f in ~/.config/zsh/functions/*.zsh; source $f'

  mkdir -p "$dir"
  echo "→ Downloading gfork.zsh → $dest"
  curl -fsSL "$BASE_URL/gfork.zsh" -o "$dest"

  echo "→ Ensuring loader in $rc"
  add_line_if_missing "$rc" "$loader"

  # Load into current session if we're already in zsh
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    # shellcheck disable=SC1090
    source "$dest"
  fi

  echo "✓ Installed for zsh"
  echo "  Functions dir: $dir"
  echo "  Drop any *.zsh file there and it loads automatically."
}

install_bash() {
  local dir="${GFORK_BASH_DIR:-$HOME/.config/bash/functions}"
  local dest="$dir/gfork.bash"
  local rc="$HOME/.bashrc"
  local loader='for f in ~/.config/bash/functions/*.bash; do source "$f"; done'

  mkdir -p "$dir"
  echo "→ Downloading gfork.bash → $dest"
  curl -fsSL "$BASE_URL/gfork.bash" -o "$dest"

  echo "→ Ensuring loader in $rc"
  add_line_if_missing "$rc" "$loader"

  # Load into current session
  # shellcheck disable=SC1090
  source "$dest"

  echo "✓ Installed for bash"
  echo "  Functions dir: $dir"
  echo "  Drop any *.bash file there and it loads automatically."
}

install_fish() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions"
  local dest="$dir/gfork.fish"
  mkdir -p "$dir"
  echo "→ Downloading gfork.fish → $dest"
  curl -fsSL "$BASE_URL/gfork.fish" -o "$dest"
  echo "✓ Installed for fish"
  echo "  fish auto-loads everything in $dir — no config change needed."
}

install_nu() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/nushell"
  local dest="$dir/gfork.nu"
  local config="$dir/config.nu"
  local loader='source ~/.config/nushell/gfork.nu'
  mkdir -p "$dir"
  echo "→ Downloading gfork.nu → $dest"
  curl -fsSL "$BASE_URL/gfork.nu" -o "$dest"
  echo "→ Ensuring loader in $config"
  add_line_if_missing "$config" "$loader"
  echo "✓ Installed for nushell"
}

SHELL_NAME="$(detect_shell)"
echo "Detected shell: $SHELL_NAME"
echo ""

case "$SHELL_NAME" in
  fish)            install_fish ;;
  nu|nushell)      install_nu   ;;
  zsh)             install_zsh  ;;
  bash)            install_bash ;;
  *)
    echo "Shell '$SHELL_NAME' not recognized — defaulting to bash"
    install_bash
    ;;
esac

echo ""
echo "─────────────────────────────────────────────"
echo "  gfork installed ✓"
echo ""
echo "  Restart your shell or open a new tab, then:"
echo ""
echo "    gfork <feature-name>           # create a clone"
echo "    gfork cd <feature-name>        # jump into it"
echo "    gfork rm <feature-name>        # clean up when done"
echo "    gfork ls                       # list clones"
echo "    gfork update                   # update to latest"
echo ""
echo "  Docs: https://github.com/jax-agent/gfork"
echo "─────────────────────────────────────────────"
