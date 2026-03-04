# gfork Plugin for Claude Code

Claude Code slash commands for the [gfork](https://github.com/jax-agent/gfork) isolated clone workflow.

## Commands

### `/gfork <feature-name>`
Creates an isolated gfork clone for a feature. Use when you want a safe sandbox to experiment in — gfork clones are disposable and can't corrupt your main repo.

```
/gfork fix-payments
/gfork auth-refactor
```

### `/gfork-agent <feature-name> <task>`
Creates a gfork clone **and** launches a Claude Code sub-agent inside it in a tmux session. The agent works autonomously on the task in its own isolated environment.

```
/gfork-agent fix-payments "Fix the Stripe webhook handler to retry on 5xx errors"
/gfork-agent auth-refactor "Refactor the auth module to use JWT instead of sessions"
```

### `/gfork-parallel`
Launches multiple gfork clones with parallel agents, each working on a different task simultaneously. Best for large features you want to parallelize across independent sub-tasks.

```
/gfork-parallel
```
Then describe your tasks when prompted.

## Install

```bash
claude plugin install github.com/jax-agent/gfork/plugin
```

Or manually:
```bash
cp -r plugin/commands ~/.claude/plugins/gfork/
```

## Requirements

- [gfork](https://github.com/jax-agent/gfork) installed: `curl -fsSL https://raw.githubusercontent.com/jax-agent/gfork/main/install.sh | bash`
- [tmux](https://github.com/tmux/tmux) for agent sessions
- Claude Code with root bypass for agent mode: `CLAUDE_CODE_ALLOW_ROOT=1`
