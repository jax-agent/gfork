#!/usr/bin/env bash
# gfork — compatibility shim
# https://github.com/jax-agent/gfork
#
# This file exists for backwards compatibility only.
# The canonical shell-specific files are:
#   gfork.bash  — bash (~/.config/bash/functions/gfork.bash)
#   gfork.zsh   — zsh  (~/.config/zsh/functions/gfork.zsh)
#
# Run the installer for a clean setup:
#   curl -fsSL https://raw.githubusercontent.com/jax-agent/gfork/main/install.sh | bash

# Detect shell and source the right file, or fall back to bash
if [[ -n "${ZSH_VERSION:-}" ]]; then
  source "$(dirname "${(%):-%x}")/gfork.zsh"
else
  source "$(dirname "${BASH_SOURCE[0]}")/gfork.bash"
fi
