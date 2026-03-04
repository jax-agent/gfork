# gfork Plugin for Claude Code

Claude Code slash commands for the [gfork](https://github.com/jax-agent/gfork) isolated clone workflow.

## Commands

| Command | Description |
|---|---|
| `/gfork <feature-name>` | Create an isolated clone of the current repo for a feature |
| `/gfork-agent <feature-name> <task>` | Create a clone and launch a Claude Code agent inside it |
| `/gfork-parallel` | Launch multiple clones with parallel agents simultaneously |

## Quick start

```bash
# Inside a Claude Code session, in any repo:

/gfork fix-payments
# → ~/.gfork/my-app--fix-payments/ ready to use

/gfork-agent fix-payments Fix the Stripe webhook handler to retry on 5xx errors
# → agent running in tmux session "fix-payments"

/gfork-parallel
# → describe your tasks, agents spin up in parallel
```

## Requirements

- [gfork](https://github.com/jax-agent/gfork) installed
- [tmux](https://github.com/tmux/tmux) installed (for `/gfork-agent` and `/gfork-parallel`)

## Full documentation

📖 [docs/claude-code-plugin.md](../docs/claude-code-plugin.md) — install instructions, detailed command reference, examples, and troubleshooting.
