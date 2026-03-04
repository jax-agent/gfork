---
allowed-tools: Bash(gfork:*), Bash(git:*), Bash(tmux:*), Bash(ls:*), Bash(echo:*), Bash(basename:*), Bash(source:*), Bash(type:*), Bash(cat:*), Bash(printf:*)
description: Spin up multiple gfork clones with parallel Claude Code agents
---

Create multiple isolated gfork clones and launch a Claude Code agent in each, running in parallel.

The user must provide a list of tasks. Each task needs:
- A short feature name (slug)
- A task description

If not provided, ask for the task list before proceeding.

Follow these steps:

1. Ensure gfork is available:
   ```bash
   type gfork 2>/dev/null || source ~/.config/bash/functions/gfork.bash 2>/dev/null
   ```

2. Get the repo name:
   ```bash
   REPO=$(basename $(git rev-parse --show-toplevel))
   ```

3. For EACH task, in sequence (cloning is fast — hardlinks):
   a. Create the clone: `gfork <feature-name>`
   b. Write a TASK.md into the clone with the task description and these instructions:
      - Create a branch: `git checkout -b feat/<feature-name>`
      - Run tests before finishing
      - Commit changes with a clear message
      - Do NOT push to origin
      - Delete TASK.md when done
   c. Create a tmux session: `tmux new-session -d -s <feature-name> -c ~/.gfork/${REPO}--<feature-name>`
   d. Launch Claude Code: `tmux send-keys -t <feature-name> "CLAUDE_CODE_ALLOW_ROOT=1 claude --permission-mode bypassPermissions 'Read TASK.md and complete the task.'" Enter`

4. After all agents are launched, print a summary table:
   ```
   Agent         Clone Path                                  Session
   ─────────────────────────────────────────────────────────────────
   fix-auth      ~/.gfork/my-app--fix-auth/                 fix-auth
   api-layer     ~/.gfork/my-app--api-layer/                api-layer
   ```

5. Tell the user how to monitor:
   - Watch all: `tmux ls`
   - Attach to one: `tmux attach -t <name>`
   - Peek without attaching: `tmux capture-pane -t <name> -p`

6. Tell the user how to collect results when done:
   - For each clone: `cd ~/.gfork/<repo>--<name> && git diff main`
   - Cherry-pick or merge commits back into the main repo
   - Delete clones: `gfork rm <name>`
