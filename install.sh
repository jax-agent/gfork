#!/usr/bin/env bash
# gfork installer — auto-detects your shell
# https://github.com/jax-agent/gfork
set -e

BASE_URL="https://raw.githubusercontent.com/jax-agent/gfork/main"

detect_shell() {
  # Check current shell process
  local shell_name
  shell_name="$(basename "${SHELL:-}")"

  # Also check if we're running inside fish/nu (they might invoke bash for scripts)
  if [[ -n "${FISH_VERSION:-}" ]]; then shell_name="fish"; fi
  if [[ -n "${NU_VERSION:-}" ]]; then shell_name="nu"; fi

  echo "$shell_name"
}

install_bash_zsh() {
  local rc_file="$1"
  local dest="$HOME/.gfork.sh"
  echo "→ Downloading gfork.sh..."
  curl -fsSL "$BASE_URL/gfork.sh" -o "$dest"
  local line='source ~/.gfork.sh'
  if ! grep -qF "$line" "$rc_file" 2>/dev/null; then
    printf '\n# gfork — git local clone workflow\n%s\n' "$line" >> "$rc_file"
    echo "→ Added to $rc_file"
  else
    echo "→ Already in $rc_file (skipping)"
  fi
  # shellcheck disable=SC1090
  source "$dest"
  echo "✓ Installed for bash/zsh"
}

install_fish() {
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions/gfork.fish"
  mkdir -p "$(dirname "$dest")"
  echo "→ Downloading gfork.fish..."
  curl -fsSL "$BASE_URL/gfork.fish" -o "$dest"
  echo "✓ Installed for fish: $dest"
  echo "  (functions/ directory is auto-loaded — no config change needed)"
}

install_nu() {
  local nu_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nushell"
  local dest="$nu_dir/gfork.nu"
  local config="$nu_dir/config.nu"
  mkdir -p "$nu_dir"
  echo "→ Downloading gfork.nu..."
  curl -fsSL "$BASE_URL/gfork.nu" -o "$dest"
  local line="source ~/.config/nushell/gfork.nu"
  if ! grep -qF "$line" "$config" 2>/dev/null; then
    printf '\n# gfork — git local clone workflow\n%s\n' "$line" >> "$config"
    echo "→ Added to $config"
  else
    echo "→ Already in $config (skipping)"
  fi
  echo "✓ Installed for nushell"
}

SHELL_NAME="$(detect_shell)"
echo "Detected shell: $SHELL_NAME"
echo ""

case "$SHELL_NAME" in
  fish)
    install_fish
    ;;
  nu|nushell)
    install_nu
    ;;
  zsh)
    install_bash_zsh "$HOME/.zshrc"
    ;;
  bash)
    install_bash_zsh "$HOME/.bashrc"
    ;;
  *)
    echo "Shell '$SHELL_NAME' not auto-detected — installing for bash/zsh"
    install_bash_zsh "$HOME/.bashrc"
    ;;
esac

echo ""
echo "─────────────────────────────────────────────"
echo "  gfork installed ✓"
echo ""
echo "  Usage:"
echo "    gfork <feature-name>           # clone current branch"
echo "    gfork <feature-name> <branch>  # clone specific branch"
echo ""
echo "  Docs: https://github.com/jax-agent/gfork"
echo "─────────────────────────────────────────────"
