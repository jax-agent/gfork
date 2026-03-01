#!/usr/bin/env bash
# gfork installer
set -e

GFORK_URL="https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.sh"
DEST="$HOME/.gfork.sh"
SHELL_RC=""

# Detect shell config
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC="$HOME/.profile"
fi

echo "→ Downloading gfork..."
curl -fsSL "$GFORK_URL" -o "$DEST"

SOURCE_LINE='source ~/.gfork.sh'
if ! grep -qF "$SOURCE_LINE" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# gfork — git local clone workflow" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  echo "→ Added to $SHELL_RC"
else
  echo "→ Already in $SHELL_RC (skipping)"
fi

# Source now
# shellcheck disable=SC1090
source "$DEST"

echo ""
echo "✓ gfork installed. Restart your shell or run: source ~/.gfork.sh"
echo ""
echo "Usage:"
echo "  gfork <feature-name>              # clone current branch"
echo "  gfork <feature-name> <branch>     # clone specific branch"
