# CLAUDE.md — gfork

## What this project is

`gfork` is a shell utility that creates isolated local git clones for parallel
development. One command, one clone, one sandbox. When the work is done, push
and delete it.

## Why it exists

AI coding agents — Claude Code, Codex, OpenCode, and others — are powerful but
they share a fundamental problem: they all want to work in *your* repo, on
*your* working tree, touching *your* index.

Run two agents at once and they fight. One checks out a branch the other needs.
One stages files the other is trying to read. One rewrites a file mid-merge.
The result is a corrupted working tree, a confused agent, or both.

Git worktrees help but don't fully solve it. Worktrees share the same `.git`
directory, which means they share the ref namespace. You can't check out the
same branch in two worktrees. Two agents writing to the same ref simultaneously
will corrupt it. The original repo is always one bad command away from being
in a broken state.

`gfork` takes a different approach: **give each agent its own `.git`**. A full
local clone, hardlinked so it's instant and cheap, completely isolated so
nothing inside it can touch the original. Agents can create branches, force
push, reset hard, blow up the index — none of it matters. The real repo is
untouched.

## The mental model

Think of `gfork` as a scratch pad. You hand it to an agent, it does its work,
you take the commits you want, and you throw the scratch pad away.

```
your-repo/              ← protected. agents never touch this.
your-repo--feature-a/   ← agent 1 lives here
your-repo--feature-b/   ← agent 2 lives here
your-repo--experiment/  ← you're exploring something, no agent involved
```

Each clone is disposable. That's the point. When you stop treating the working
tree as precious, you stop being afraid to let agents run freely.

## Why `git clone --local` and not `cp -r`

`git clone --local` uses hardlinks for git object storage. On a 2GB repo, the
clone is nearly instant and adds almost nothing to disk usage. The clone also
knows its origin automatically, so `git push` and `git pull` just work without
any extra setup.

`cp -r` would copy every object file, be slow, use double the disk, and lose
the remote tracking configuration.

## Design decisions

**No flags, just subcommands.** `gfork <name>` creates. `gfork cd`, `gfork rm`,
`gfork ls` manage. The surface area is intentionally small. This tool does one
thing.

**Safety warnings on `gfork rm`.** Before deleting a clone, we check for
uncommitted changes and unpushed commits and warn loudly. The clone is meant to
be disposable, but not at the cost of losing work.

**`gfork cd` must be a shell function.** A subprocess cannot change the parent
shell's working directory. This is why `gfork` is sourced, not executed. All
four shell implementations (bash, zsh, fish, nushell) handle this correctly.

**Naming convention is load-bearing.** Clones are always named
`repo--feature`. This is how `gfork ls` finds them (glob `repo--*` in the
parent dir) and how `gfork rm` and `gfork cd` resolve short feature names to
full paths. Don't rename clones manually.

## What to do when working in a clone

Drop an `AGENTS.md` or `CLAUDE.md` in the clone root to give agents context
about the environment. Tell them: they're in an isolated clone, they should
create branches freely, they should not push to origin (you'll handle that),
and they should run tests before merging branches back to the clone's main.

Example:

```markdown
You are working in an isolated clone of this repo.
- Create a branch for each logical unit of work
- Merge branches back to main as they complete
- Do not push to origin — the human will handle that
- Run tests before merging: `npm test`
```

## What this project is not

- Not a branching strategy
- Not a CI tool
- Not a replacement for git worktrees in all cases (worktrees are great for
  single-agent, single-branch work)
- Not opinionated about how you structure work inside the clone

## Contributing

Keep it simple. The whole thing is shell functions — no dependencies, no build
step, no package manager. If a change requires a dependency, reconsider the
change. If a change adds significant complexity, question whether it belongs
here or in a separate tool.

Tests live in `tests/gfork.bats` and run with `bats tests/gfork.bats`. Add a
test for every new behavior.
