# gfork

A tiny shell function that creates an isolated local clone of your git repo — purpose-built for AI agent workflows and long-running feature development.

## The Problem

When you hand a codebase to an AI agent (Claude Code, Codex, Cursor, etc.), it needs freedom to create branches, experiment, and make mistakes — without touching your real repo. Git worktrees help, but they share a `.git` directory and can't check out the same branch twice.

**gfork solves this with a dead-simple pattern:** clone locally, work freely, push when done, delete clone.

## The Workflow

```
main repo                       clone (your sandbox)
─────────────────               ──────────────────────────────────
antmachine/          →  gfork   antmachine--memory-system/
  (your real repo)                agents create branches freely:
                                    belief-actor
                                    notes-actor
                                    graph-persistence
                                  all merge into clone's main
                                  ↓
                                git push origin main  (or open PR)
                                ↓
                              cd ../antmachine && git pull
                              rm -rf ../antmachine--memory-system
```

## Install

**Option 1: Source in your shell config (recommended)**

```bash
# Download
curl -o ~/.gfork.sh https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.sh

# Add to ~/.zshrc or ~/.bashrc
echo 'source ~/.gfork.sh' >> ~/.zshrc
source ~/.zshrc
```

**Option 2: Copy-paste the function**

Copy `gfork.sh` into your `~/.zshrc` or `~/.bashrc` directly.

## Usage

```bash
# Fork the current branch into a sibling directory
gfork <feature-name>

# Fork from a specific branch
gfork <feature-name> <source-branch>
```

### Example

```bash
# You're in ~/projects/antmachine on main
gfork memory-system
# → Creates ~/projects/antmachine--memory-system/ cloned from main

cd ../antmachine--memory-system

# AI agents (or you) create branches freely:
git checkout -b belief-actor
# ... work ...
git checkout main && git merge belief-actor

git checkout -b notes-actor
# ... work ...
git checkout main && git merge notes-actor

# Feature complete:
git push origin main        # push to GitHub (or open a PR)
cd ../antmachine            # back to original
git pull                    # pull changes
rm -rf ../antmachine--memory-system   # clean up clone
```

## Why not git worktrees?

| | gfork | git worktree |
|---|---|---|
| Isolated `.git` | ✓ | ✗ (shared) |
| Same branch in two places | ✓ | ✗ |
| Unlimited sub-branches | ✓ | ✓ |
| AI agents can't corrupt real repo | ✓ | ✗ |
| Disk usage | low (hardlinks) | lower |
| Clean lifecycle | clone → work → delete | manual prune |

## Why not `cp -r`?

`git clone --local` uses hardlinks for git objects — it's near-instant and doesn't duplicate object storage. The clone also knows its origin, so push/pull just works.

## License

MIT
