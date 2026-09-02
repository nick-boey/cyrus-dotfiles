# cyrus-dotfiles

Dotfiles repo for [Cyrus](https://github.com/nick-boey/cyrus) sandboxes. It
installs shared agent skills for Claude Code and Codex so they are available to
every Cyrus session.

## What it does

`install.sh` clones [Matt Pocock's skills](https://github.com/mattpocock/skills)
at a pinned commit and copies the 25 skills the published plugin ships
(`skills/engineering/` and `skills/productivity/`) into both
`~/.claude/skills/` and `~/.codex/skills/`. Before copying each third-party
skill, it checks that application's mattpocock plugin cache, the shared
`~/.agents/skills/` directory, and the application's own skill directory; an
existing skill is reported and skipped. It also installs this repository's
`plan-review` and `implementation-review` skills into both application-specific
locations, replacing only those repository-owned skills on reruns.

Cyrus runs it on every container boot, before `cyrus start`
(`ContainerBootCommand.applyDotfiles`). It is idempotent, and a failure is
logged and swallowed rather than blocking the boot.

11 of the third-party skills are model-invocable (`code-review`, `codebase-design`,
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

## Adversarial reviews

The two repository-owned review skills are model-invokable but run only after
an explicit review request or an explicitly invoked workflow checkpoint:

- `plan-review` reviews plans supplied through Linear issues, projects, or
  initiatives, plan files, documents, or conversation context. A Linear plan
  includes its normative descendant hierarchy.
- `implementation-review` reviews pull requests, branch diffs, or working-tree
  changes and compares them with an optional plan.

Both are read-only. In Claude they prefer the Codex CLI and fall back to a
fresh Claude reviewer; in Codex they prefer the Claude Code CLI and fall back
to a fresh Codex reviewer. Their output records the reviewer path, model,
evidence completeness, and independence level. Required inaccessible evidence
produces an `inconclusive` verdict rather than a partial approval.

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

Run the command twice with the same temporary `HOME` to verify idempotence.
The second run should report each existing third-party skill and skip it while
updating `plan-review` and `implementation-review`.
