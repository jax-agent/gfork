---
allowed-tools: Bash(gfork:*), Bash(git:*), Bash(tmux:*), Bash(ls:*), Bash(echo:*), Bash(basename:*), Bash(source:*), Bash(type:*), Bash(CLAUDE_CODE_ALLOW_ROOT=1:*)
description: Spin up a gfork clone and launch a Claude Code agent inside it
---

Create an isolated gfork clone and launch a Claude Code sub-agent inside it to work on the given task.

The user must provide:
- **Feature name** — short slug for the clone (e.g. `fix-auth`, `api-layer`)
- **Task** — what the agent should do inside the clone

If either is missing, ask for it before proceeding.

Follow these steps:

1. Ensure gfork is available (source the bash function if needed):
   ```bash
   type gfork 2>/dev/null || source ~/.config/bash/functions/gfork.bash 2>/dev/null
   ```

2. Get the repo name:
   ```bash
   REPO=$(basename $(git rev-parse --show-toplevel))
   ```

3. Create the clone:
   ```bash
   gfork <feature-name>
   CLONE_PATH=~/.gfork/${REPO}--<feature-name>
   ```

4. Write a task file into the clone so the agent has clear instructions:
   ```bash
   cat > $CLONE_PATH/TASK.md << 'EOF'
   # Task

   <task description>

   ## Instructions
   - You are working in an isolated clone of this repo. Work freely.
   - Create a branch for your work: `git checkout -b feat/<feature-name>`
   - Run tests before finishing.
   - Commit your changes with a clear message.
   - Do NOT push to origin — the human will review and push.
   - Delete this TASK.md when done.
   EOF
   ```

5. Create a tmux session and launch Claude Code:
   ```bash
   tmux new-session -d -s <feature-name> -c $CLONE_PATH
   tmux send-keys -t <feature-name> "CLAUDE_CODE_ALLOW_ROOT=1 claude --permission-mode bypassPermissions 'Read TASK.md and complete the task.'" Enter
   ```

6. Report to the user:
   - **Clone path:** `~/.gfork/<repo>--<feature-name>/`
   - **tmux session:** `<feature-name>` — monitor with `tmux attach -t <feature-name>` or `tmux capture-pane -t <feature-name> -p`
   - **When agent finishes:** review the diff, then push the branch from inside the clone

Do not wait for the agent to finish. Background it and report the session name.
