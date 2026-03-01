# gfork

> Isolated git clone workflow for AI agent and parallel feature development.

One command creates a full local clone of your repo in a sibling folder. AI agents work freely inside — as many branches as they want — without touching your real repo. When done: push, pull, delete clone.

```
your-repo/              →  gfork big-feature  →  your-repo--big-feature/
  (protected)                                       (agents go wild here)
```

---

## Install

**One-liner (auto-detects your shell):**
```bash
curl -fsSL https://raw.githubusercontent.com/jax-agent/gfork/main/install.sh | bash
```

**Manual install by shell:**

**zsh** — installs to `~/.config/zsh/functions/`, adds one generic loader to `.zshrc`:
```zsh
mkdir -p ~/.config/zsh/functions
curl -o ~/.config/zsh/functions/gfork.zsh \
  https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.zsh
echo "for f in ~/.config/zsh/functions/*.zsh; source \$f" >> ~/.zshrc
```

**bash** — installs to `~/.config/bash/functions/`, adds one generic loader to `.bashrc`:
```bash
mkdir -p ~/.config/bash/functions
curl -o ~/.config/bash/functions/gfork.bash \
  https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.bash
echo 'for f in ~/.config/bash/functions/*.bash; do source "$f"; done' >> ~/.bashrc
```

**fish** — drop in `~/.config/fish/functions/`, fish auto-loads it:
```bash
curl -o ~/.config/fish/functions/gfork.fish \
  https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.fish
```

**nushell**:
```bash
curl -o ~/.config/nushell/gfork.nu \
  https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.nu
echo 'source ~/.config/nushell/gfork.nu' >> ~/.config/nushell/config.nu
```

---

## Usage

```bash
gfork <feature-name>              # clone current branch
gfork <feature-name> <branch>     # clone a specific branch
gfork cd <feature-name>           # cd into an existing clone
gfork rm <feature-name>           # delete a clone (with confirmation)
gfork ls                          # list all clones for this repo
```

> **Note (nushell):** cd is a built-in, so the commands are `gfork-cd`, `gfork-rm`, and `gfork-ls` instead.

**Output:**
```
⎇  Cloning 'main' → /projects/antmachine--memory-system
✓ Clone ready: /projects/antmachine--memory-system

  cd antmachine--memory-system
  # When done: gfork rm memory-system
```

---

## The Workflow

```bash
# 1. You're in your real repo on main
cd ~/projects/my-app
gfork big-feature

# 2. Jump into the clone in one command
gfork cd big-feature              # ← drops you straight in

# 3. Agents create branches freely inside the clone
git checkout -b auth-system      # agent 1
# ... work ...
git checkout main && git merge auth-system

git checkout -b payment-flow     # agent 2
# ... work ...
git checkout main && git merge payment-flow

git checkout -b email-templates  # agent 3
# ... work ...
git checkout main && git merge email-templates

# 4. Feature complete — push and clean up
git push origin main
cd ~/projects/my-app             # back to real repo
git pull                         # pull the merged changes
gfork rm big-feature             # ← confirms, warns if unpushed, then deletes

# Or list what clones you have
gfork ls
#   my-app--big-feature  (gfork cd big-feature)
#   my-app--experiment   (gfork cd experiment)
```

---

## Using gfork with AI Agents

### Claude Code

Claude Code works great inside a gfork clone. Each agent session gets full branch freedom.

```bash
cd ~/projects/my-app
gfork refactor-v2
cd ../my-app--refactor-v2

# Run Claude Code inside the clone
CLAUDE_CODE_ALLOW_ROOT=1 claude -p "
  Refactor the authentication module to use JWT.
  Create a feature branch called 'jwt-auth', do all your work there,
  run the tests, and merge back to main when passing.
" --output-format text

# Agent creates branches, merges, you never touch the real repo
git push origin main
cd ~/projects/my-app && git pull
gfork rm refactor-v2
```

**With parallel agents:**
```bash
gfork parallel-sprint
cd ../my-app--parallel-sprint

# Spin up multiple Claude Code agents simultaneously
CLAUDE_CODE_ALLOW_ROOT=1 claude -p "Build the user dashboard on branch 'dashboard'" &
CLAUDE_CODE_ALLOW_ROOT=1 claude -p "Build the API layer on branch 'api-layer'" &
CLAUDE_CODE_ALLOW_ROOT=1 claude -p "Write the test suite on branch 'tests'" &
wait

# Review and merge what you want
git merge dashboard
git merge api-layer
git merge tests
```

---

### Codex (OpenAI)

```bash
cd ~/projects/my-app
gfork codex-feature
cd ../my-app--codex-feature

# Point Codex at the clone
codex "Add Stripe billing support. Work in a feature branch, 
       merge to main when complete."

git push origin main
cd ~/projects/my-app && git pull
gfork rm codex-feature
```

---

### OpenCode

```bash
cd ~/projects/my-app
gfork opencode-sprint
cd ../my-app--opencode-sprint

# OpenCode works in isolated clone
opencode "Implement the notification system end-to-end.
          Use sub-branches per component, merge when done."

git push origin main
cd ~/projects/my-app && git pull
gfork rm opencode-sprint
```

---

### Pi Agent (Perplexity)

```bash
cd ~/projects/my-app
gfork pi-research
cd ../my-app--pi-research

# Pi agent does research-heavy tasks in isolation
pi "Research and implement the best caching strategy for this codebase.
    Try different approaches in separate branches, benchmark, keep the winner."

git push origin main
cd ~/projects/my-app && git pull
gfork rm pi-research
```

---

### Pro tip: CLAUDE.md / AGENTS.md inside the clone

Drop an instruction file in the clone root to give agents context:

```bash
gfork payment-feature
cd ../my-app--payment-feature

cat > AGENTS.md << 'EOF'
You are working in an isolated clone of my-app.
- Create a branch for each logical unit of work
- Merge branches back to main as they complete  
- Never push to origin — I will handle that
- Run tests before merging: `mix test` / `npm test` / `pytest`
EOF

claude -p "Implement Stripe billing per AGENTS.md"
```

---

## Why not git worktrees?

| | gfork | git worktree |
|---|---|---|
| Isolated `.git` | ✓ | ✗ shared |
| Same branch name in two places | ✓ | ✗ |
| AI agents can't corrupt real repo | ✓ | ✗ |
| Multiple agents, zero coordination | ✓ | limited |
| Disk usage | low (hardlinks) | lower |
| Clean lifecycle | clone → work → delete | manual prune |
| Works with all tools | ✓ | some tools break |

## Why `git clone --local` over `cp -r`?

`git clone --local` uses hardlinks for git objects — near-instant even on large repos, minimal extra disk usage. The clone knows its origin so `git push`/`git pull` just work.

---

## Shell Support

| Shell | File | Install location | Loader in rc file |
|-------|------|-----------------|-------------------|
| **zsh** | `gfork.zsh` | `~/.config/zsh/functions/gfork.zsh` | `for f in ~/.config/zsh/functions/*.zsh; source $f` |
| **bash** | `gfork.bash` | `~/.config/bash/functions/gfork.bash` | `for f in ~/.config/bash/functions/*.bash; do source "$f"; done` |
| **fish** | `gfork.fish` | `~/.config/fish/functions/gfork.fish` | *(auto-loaded, no change needed)* |
| **nushell** | `gfork.nu` | `~/.config/nushell/gfork.nu` | `source ~/.config/nushell/gfork.nu` |

The zsh and bash loader lines are generic — once added, any shell function you install to that directory is picked up automatically. No more touching your rc file for every new tool.

---

## Man Page

A full man page is included.

```bash
sudo cp gfork.1 /usr/local/share/man/man1/
sudo mandb
man gfork
```

---

## License

MIT — use freely, contributions welcome.
