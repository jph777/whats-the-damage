# Agent guide: whats-the-damage

An Omarchy shell plugin: a copy of the `omarchy.agents` bar widget that shows Destiny-style yellow damage numbers over its icon whenever an agent spends tokens.
The checkout at ~/.config/omarchy/plugins/jph777.whats-the-damage is also the live plugin the shell loads; whatever branch is checked out there is what runs.
Any agent (Claude, Codex, others) follows this file. `CLAUDE.md` only points here.

## Hard rules

1. The only remote is `origin` (`jph777/whats-the-damage`). Don't add or push to other remotes without asking.
2. **Never force-push, rewrite published history, or delete `stable` or `dev`.**
3. **Never commit directly to `stable`.** Work on a branch off `dev`.
4. **Never run `scripts/promote` yourself.** It needs the user's smoke test. Ask them to run it
   in a real terminal; the `!` prompt of agent CLIs has no tty and is refused.
5. **Never commit secrets** (tokens, API keys, credentials, `.env` files).
6. **Never spend real tokens to test.** Use the `hit <amount>` IPC command and the `tests/` suite.
7. **Don't edit `/usr/share/omarchy`.** It is system-owned and overwritten by updates; this plugin carries its own copy of the agents widget.
- If something needs a step these rules forbid and there is no sensible alternative, **stop and ask
  the user** instead of working around it. Don't use `--no-verify`.

## Branches

| Branch | Role | Who moves it |
|---|---|---|
| `dev` | Integration branch. All `feat/*`, `fix/*`, `chore/*` branches land here. | `scripts/land` |
| `stable` | Tested and smoke-tested code. GitHub default branch. What normally runs. | `scripts/promote` (user only) |

Invariant: `stable` is always an ancestor of `dev` (promotion is a fast-forward).

## Workflow

```
scripts/setup                  # once per clone: hooks + safety config + dev worktree
scripts/wt feat/my-feature        # new branch off dev in its own worktree; work and commit there
sh tests/run                      # must pass before landing
scripts/land feat/my-feature "Summary"  # feat/*: tests, SQUASH into one commit on dev, push, clean up
scripts/land fix/my-fix           # everything else: tests, merge --no-ff into dev, push, clean up
scripts/live dev                  # user: point the main checkout at dev to smoke test it
scripts/live feat/my-feature      # ...or at an unfinalized feature branch
scripts/live stable               # back to stable
scripts/promote                   # USER ONLY, in a real terminal: tests + confirm, then stable = dev, pushed
```

- **Always work in a worktree**, never in the main checkout, which is the user's running plugin: edits there change the bar immediately.
- Worktrees live in `~/Work/whats-the-damage-worktrees` (override: `WORKFLOW_WORKTREES`); they must stay **outside** ~/.config/omarchy/plugins, or the shell would discover each worktree's manifest as a duplicate plugin.
- `dev` is checked out in its own worktree, so `scripts/live dev` uses a detached checkout of dev's
  commit. Re-run it after landing something new.
- **Features are developed on their own `feat/*` branch and squash-merged into `dev`**, so each feature is
  one clearly labeled commit on the `dev` timeline. Don't land a `feat/*` branch until the user says the
  feature is finalized; test it meanwhile with `scripts/live feat/<name>`. Fixes and chores use `--no-ff`
  merges. Never squash or rewrite pushed history without asking.
- **Every branch lives on `origin` too: no local-only branches.** Push a `feat/*` (or any) branch as soon as
  you create it (`git push -u origin <branch>`) and push after every commit, so GitHub and the local
  worktree never differ. When a branch is landed or abandoned, delete it locally and on origin
  (`git push origin --delete <branch>`). Only the `backup/*` safety refs may stay local, and only briefly.
- **Delete a `feat/*` branch as soon as it is squash-merged into `dev`**, locally and on `origin`. Git never
  sees a squashed branch as merged (it is not an ancestor of `dev`), so it will not warn about it and it
  would linger. `scripts/land` does this for you (`branch -D` plus `push origin --delete`); if you merge
  by hand, delete both copies yourself, and remove its worktree. Check with `git branch -a` that no
  `feat/*` branch outlives its landing commit.
- Commit messages: short imperative subject. Keep commits focused. Don't reformat or rename unrelated code.

## Testing

- `sh tests/run` must pass before `scripts/land` and again before promotion.
- The manual smoke test is the user's: run `omarchy-shell whats-the-damage hit 1000` (no real tokens needed) and watch a yellow 1,000 pop out of the bar icon while the icon flinches. Tell them what changed and what to look at.

## Enforcement

- Git hooks (`.githooks/`, installed by `scripts/setup`; hooks are not shared by `git clone`, so
  re-run it in every new clone): no commits or merge commits on `stable`,
  no force-push or branch deletion, `stable` is pushable only via `scripts/promote`.
- GitHub branch protection on `origin`: no force-push, no deletion on the protected branches.
- Settings live in `git config workflow.*` (`testCmd`, `worktreeRoot`, `smokeTest`, `upstreamBranch`).

## Project facts

- Plugin id `jph777.whats-the-damage`; replaces `omarchy.agents` in `~/.config/omarchy/shell.json` `bar.layout.right`.
- Usage records come from `~/.local/state/omarchy/agents/usage/*.json` (written by `omarchy-agent-usage-update`).
- Test IPC: `omarchy-shell whats-the-damage hit <tokens>`.
