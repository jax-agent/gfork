# gfork Claude Code Plugin

The gfork plugin adds three slash commands to Claude Code that make it easy to spin up isolated clones, launch agents, and run parallel work — all without leaving your Claude Code session.

## Install

### Prerequisites

1. **gfork** must be installed:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/jax-agent/gfork/main/install.sh | bash
   ```

2. **tmux** must be installed (required for `/gfork-agent` and `/gfork-parallel`):
   ```bash
   # macOS
   brew install tmux
   # Ubuntu/Debian
   apt install tmux
   # Arch
   pacman -S tmux
   ```

### Install the plugin

Copy the `plugin/` directory from this repo into Claude Code's plugin cache and register it:

```bash
# Clone the repo if you haven't already
git clone https://github.com/jax-agent/gfork ~/.gfork-plugin-src

# Copy the plugin
mkdir -p ~/.claude/plugins/cache/local/gfork/1.0.0
cp -r ~/.gfork-plugin-src/plugin/. ~/.claude/plugins/cache/local/gfork/1.0.0/

# Register it
python3 - << 'EOF'
import json, datetime

path = '/root/.claude/plugins/installed_plugins.json'  # adjust if needed
with open(path) as f:
    data = json.load(f)

key = "gfork@local"
entry = {
    "scope": "user",
    "installPath": f"{__import__('os').path.expanduser('~')}/.claude/plugins/cache/local/gfork/1.0.0",
    "version": "1.0.0",
    "installedAt": datetime.datetime.now(datetime.UTC).isoformat(),
    "lastUpdated": datetime.datetime.now(datetime.UTC).isoformat()
}

data["plugins"][key] = [entry]
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print("gfork plugin registered")
EOF
```

Then restart Claude Code. The `/gfork`, `/gfork-agent`, and `/gfork-parallel` commands will be available.

---

## Commands

### `/gfork <feature-name>`

Creates an isolated gfork clone for a feature. Use this when you want a safe sandbox — the clone is fully disposable and can't affect your main repo.

**Example:**
```
/gfork fix-payments
```

**What happens:**
1. Runs `gfork fix-payments` from the current repo
2. Clone is created at `~/.gfork/<repo>--fix-payments/`
3. Reports the path, how to navigate in, and how to delete it when done

**Use this when:**
- You want to hand off a task to an agent manually
- You want to experiment without risk
- You're setting up for a long autonomous agent run

---

### `/gfork-agent <feature-name> <task>`

Creates a gfork clone **and** launches a Claude Code sub-agent inside it in a background tmux session. The agent works autonomously on the task in full isolation.

**Example:**
```
/gfork-agent fix-payments Fix the Stripe webhook handler to retry on 5xx errors and add tests
```

**What happens:**
1. Creates the clone at `~/.gfork/<repo>--fix-payments/`
2. Writes a `TASK.md` into the clone with the task and standard instructions (branch, test, commit, don't push)
3. Starts a tmux session named `fix-payments`
4. Launches `claude --permission-mode bypassPermissions 'Read TASK.md and complete the task.'` inside it
5. Returns immediately with the session name and how to monitor it

**Monitor the agent:**
```bash
# Attach (interactive)
tmux attach -t fix-payments

# Peek without interrupting
tmux capture-pane -t fix-payments -p

# Detach once attached
# Ctrl+B then D
```

**When the agent finishes:**
```bash
# Review what it did
cd ~/.gfork/<repo>--fix-payments
git log --oneline main
git diff origin/main

# Push the branch to GitHub
git push origin feat/fix-payments

# Open a PR, then clean up the clone
cd ~/projects/<repo>
gfork rm fix-payments
```

---

### `/gfork-parallel`

Launches multiple gfork clones with a Claude Code agent in each, all running in parallel. Best for large features where sub-tasks are independent.

**Example:**
```
/gfork-parallel
```

Claude will ask you for a list of tasks. Describe them in plain language:

```
Task 1: fix-auth — Refactor the auth module to use JWT instead of sessions
Task 2: api-layer — Add pagination to all list endpoints
Task 3: test-suite — Write integration tests for the checkout flow
```

**What happens:**
1. Creates one clone per task: `~/.gfork/<repo>--fix-auth/`, `~/.gfork/<repo>--api-layer/`, etc.
2. Writes a `TASK.md` into each clone
3. Starts a tmux session per task
4. Launches an agent in each session simultaneously
5. Returns a summary table of all sessions

**Monitor all agents:**
```bash
tmux ls
# fix-auth: 1 windows (created ...)
# api-layer: 1 windows (created ...)
# test-suite: 1 windows (created ...)

# Peek at one
tmux capture-pane -t fix-auth -p

# Attach to one
tmux attach -t api-layer
```

**Collect results:**
```bash
# Review each clone
for name in fix-auth api-layer test-suite; do
  echo "=== $name ==="
  cd ~/.gfork/<repo>--$name
  git log --oneline main
done

# Push branches you're happy with
cd ~/.gfork/<repo>--fix-auth && git push origin feat/fix-auth
cd ~/.gfork/<repo>--api-layer && git push origin feat/api-layer

# Clean up
cd ~/projects/<repo>
gfork rm fix-auth
gfork rm api-layer
gfork rm test-suite
```

---

## How agents behave inside clones

Each agent receives a `TASK.md` with these instructions baked in:

- Create a branch for the work: `git checkout -b feat/<feature-name>`
- Run tests before finishing
- Commit with a clear message
- **Do not push to origin** — you handle that after reviewing
- Delete `TASK.md` when done

This keeps the agent scoped, testable, and non-destructive. You stay in control of what reaches GitHub.

---

## Example: full parallel sprint

```bash
# You're inside a Claude Code session in ~/projects/my-app
/gfork-parallel

# Describe your sprint tasks:
# 1. dashboard — Build the user dashboard page with stats cards and activity feed
# 2. notifications — Add email + in-app notification system
# 3. onboarding — Create the onboarding wizard flow (3 steps)

# Three agents spin up in parallel in isolated clones.
# You keep working in your main session while they run.

# 30 minutes later — check in:
tmux capture-pane -t dashboard -p | tail -20
tmux capture-pane -t notifications -p | tail -20
tmux capture-pane -t onboarding -p | tail -20

# Agents done. Review + push what passed:
cd ~/.gfork/my-app--dashboard && git diff origin/main | head -50
git push origin feat/dashboard

# Open PRs on GitHub, merge, clean up
cd ~/projects/my-app
gfork rm dashboard
gfork rm notifications
gfork rm onboarding
```

---

## Troubleshooting

**`gfork: command not found` inside the agent session**

The agent's shell may not source your rc file. The plugin handles this by explicitly sourcing:
```bash
source ~/.config/bash/functions/gfork.bash 2>/dev/null
source ~/.config/zsh/functions/gfork.zsh 2>/dev/null
```
If it still fails, ensure gfork is installed at one of those paths.

**tmux session already exists**

If you already have a session with that name, the agent launch will fail. Kill the old one first:
```bash
tmux kill-session -t <name>
```

**Agent ran as root but permission denied**

Pass `CLAUDE_CODE_ALLOW_ROOT=1` — the plugin does this automatically but verify your Claude Code version supports the env var.

**Clone already exists**

`gfork` will error if a clone with that name already exists. Either use a different name or delete the old clone first:
```bash
gfork rm <feature-name>
```
