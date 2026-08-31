# cyrus-dotfiles

Dotfiles repo for [Cyrus](https://github.com/nick-boey/cyrus) sandboxes. It
installs [Matt Pocock's agent skills](https://github.com/mattpocock/skills) into
`~/.claude/skills/` so they are available to every Cyrus session.

## What it does

`install.sh` clones `mattpocock/skills` at a pinned commit and copies the 25
skills the published `mattpocock-skills` plugin ships (`skills/engineering/` and
`skills/productivity/`) into `~/.claude/skills/`. Nothing else.

Cyrus runs it on every container boot, before `cyrus start`
(`ContainerBootCommand.applyDotfiles`). It is idempotent, and a failure is
logged and swallowed rather than blocking the boot.

11 of the 25 are model-invocable (`code-review`, `codebase-design`,
`diagnosing-bugs`, `domain-modeling`, `grilling`, `prototype`, `research`,
`resolving-merge-conflicts`, `tdd`, `wizard`, `writing-for-agents`). The other
14 set `disable-model-invocation: true` and are only reachable as
`/slash-commands`.

## Using it with Cyrus

Set these per-teammate environment variables on the router's `/setup` page:

| Variable | Value |
| -- | -- |
| `DOTFILES_REPO` | `https://github.com/nick-boey/cyrus-dotfiles` |
| `CYRUS_DEFAULT_SKILLS` | `summarize,verify-and-ship` |

`CYRUS_DEFAULT_SKILLS` trims Cyrus's own bundled skills. `summarize` and
`verify-and-ship` are product plumbing rather than workflow opinion —
`summarize` streams the final message into the Linear agent session and
`verify-and-ship` is what opens the pull request. None of Matt's skills replace
either. Set it to `none` only if you supply your own equivalents; otherwise
sessions silently stop opening PRs and stop posting summaries.

Requires a Cyrus router and worker built from commit `a6f24ed` or later
(NOR-365) — earlier builds never read `~/.claude/skills/`, so `install.sh` would
succeed and the skills would still be invisible to the model.

## Bumping the skills

Edit `SKILLS_SHA` in `install.sh`. The current pin matches what the
`claude-plugins-official` marketplace ships as `mattpocock-skills`.

## Testing locally

```sh
HOME=$(mktemp -d) sh install.sh
```
