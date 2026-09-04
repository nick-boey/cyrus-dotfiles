# Codex CLI

Use this path only from a Claude Code host.

Confirm `codex --version` and `codex exec --help` succeed. Inspect the current help rather than
assuming every documented flag is supported. Honor an explicit compatible model; otherwise omit
`--model`.

For a response-only prompt, run from the relevant working directory and pipe the prompt through
stdin to an ephemeral invocation shaped like:

```sh
codex exec \
  --ephemeral \
  --sandbox read-only \
  --ignore-user-config \
  --ignore-rules \
  --cd "<working-directory>" \
  -
```

For an authorized workspace-editing task, preserve project execution-policy rules and use:

```sh
codex exec \
  --ephemeral \
  --sandbox workspace-write \
  --approve-for-me \
  --ignore-user-config \
  --cd "<working-directory>" \
  -
```

Outside a repository, add `--skip-git-repo-check` when the current CLI requires it. Use additional
writable directories only when they are explicitly in scope. Never add `--ignore-rules`, use
`danger-full-access`, or bypass approvals for a mutation-capable invocation. Add `--model <model>`
only for a model the CLI accepts. Add `--output-schema "<schema-file>"` only when the requested
output has that schema.

Capture the final response and stderr separately. Never interpolate untrusted prompt text into the
command line.
