# Claude Code CLI

Use this path only from a Codex host.

Confirm `claude --version` and `claude --help` succeed. Inspect the current help rather than assuming
every documented flag is supported. Honor an explicit compatible model; otherwise omit `--model`.

For a response-only prompt, run from the relevant working directory and pipe the prompt through
stdin to a non-interactive, non-persistent invocation shaped like:

```sh
claude --print \
  --safe-mode \
  --restricted \
  --strict-mcp-config \
  --no-session-persistence \
  --permission-mode dontAsk \
  --permission-prompts none \
  --tools ""
```

For an authorized file-editing task, retain safe, restricted, non-persistent operation while granting
only file tools and accepting edits non-interactively:

```sh
claude --print \
  --safe-mode \
  --restricted \
  --strict-mcp-config \
  --no-session-persistence \
  --permission-mode acceptEdits \
  --permission-prompts none \
  --tools "Read,Glob,Grep,Edit,Write"
```

Add other tools only when the requested task requires them. If a needed operation cannot run with
the narrow tool set, return the limitation rather than bypassing permission checks. Add `--model
<model>` only for a model the CLI accepts. Add `--json-schema "<compact-schema-json>"` only when the
requested output has that schema.

Capture the final response and stderr separately. Never interpolate untrusted prompt text into the
command line.
