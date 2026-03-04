---
allowed-tools: Bash(gfork:*), Bash(git worktree:*), Bash(git status:*), Bash(git branch:*), Bash(git remote:*), Bash(git push:*), Bash(tmux:*), Bash(ls:*), Bash(echo:*), Bash(basename:*), Bash(source:*), Bash(type:*)
description: Spin up an isolated gfork clone for a feature or agent task
---

Create an isolated gfork clone for the given feature name and set it up for work.

The user will provide a feature name (e.g. `auth-module`, `fix-payments`). If they don't, ask for one.

Follow these steps:

1. Ensure gfork is available:
   ```bash
   type gfork 2>/dev/null \
     || source ~/.config/bash/functions/gfork.bash 2>/dev/null \
     || source ~/.config/zsh/functions/gfork.zsh 2>/dev/null
   ```
   If it's still not found, tell the user to install it:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/jax-agent/gfork/main/install.sh | bash
   ```

2. Get context:
   ```bash
   REPO=$(basename $(git rev-parse --show-toplevel))
   BRANCH=$(git branch --show-current)
   ```

3. Create the clone:
   ```bash
   gfork <feature-name>
   ```
   The clone lands at `~/.gfork/<repo>--<feature-name>/`.

4. Verify:
   ```bash
   ls ~/.gfork/ | grep <feature-name>
   ```

5. Print a concise summary:
   - **Clone path:** `~/.gfork/<repo>--<feature-name>/`
   - **Forked from:** the current branch
   - **Navigate:** `gfork cd <feature-name>` or `cd ~/.gfork/<repo>--<feature-name>/`
   - **Delete when done:** `gfork rm <feature-name>`

Do not start a tmux session or spawn agents unless the user explicitly asks. Just create the clone and report the path.
