---
name: implement-project-with-cyrus
description: Use when driving a whole Linear project to completion with Cyrus agents — launching implementation and review sessions from Linear comments, verifying and merging PRs, sequencing rebases, and closing parent issues. Covers the review brief patterns that actually find defects, sequencing conflicting PRs, what to escalate rather than decide, and which work the orchestrator must run itself because sandboxes cannot reach deployed infrastructure.
---

# Driving a Linear project with Cyrus

You are the orchestrator, not the implementer. Cyrus agents write the code and
review it; you decide **what runs when**, **whether a PR is safe to merge**, and
**what needs a human**. Resist the urge to implement — a session spent writing
code is a session not spent keeping five streams moving.

The one thing you do run yourself is **infrastructure**. Sandboxes cannot reach
deployed state at all, so every `az` call, live query and post-merge
verification is yours. See *What a sandbox cannot do*.

## How Cyrus works

Cyrus acts on Linear **agent-session webhooks only**. `EventRouter.handleWebhook`
handles exactly four shapes — `AgentSessionEvent/prompted`,
`AgentSessionEvent/created`, issue state change, issue deleted — and silently
drops everything else at `info` level. A comment that does not become an agent
session event **never reaches the agent**, and nothing tells you: the comment
renders normally on the issue, the sandbox keeps reporting healthy, and the
session sits idle.

### Where a comment has to land

**Two conditions, both required, or your instruction is discarded.**

1. **Every comment to an agent must mention `@cyrus1`.** Without the mention
   Linear emits `AppUserNotification/issueNewComment`, which is dropped. This is
   easy to forget on a follow-up — a rebase instruction, a CI failure, an answer
   to a question — precisely the comments a session is waiting on.
2. **Reply inside the session's thread.** A reply produces
   `AgentSessionEvent/prompted`, which always routes to the sandbox holding that
   issue. This is the only channel that reliably works.

A **top-level** `@cyrus1` comment starts a fresh session **only when no live
agent session already holds the issue**. If one does, Linear emits
`AppUserNotification/issueCommentMention` instead of creating a session, and the
router drops it. Since a session that finished its work does **not** necessarily
reach a terminal state, an issue you have already run is often in exactly this
state — so the top-level comment you send to restart it is the one most likely
to vanish.

**Default to replying in the thread.** Use a top-level comment only to start the
first session on an issue, or to get a genuinely fresh reading
(implementation → review) — and when you do, **verify it routed** rather than
assuming.

### Verifying a comment actually landed

Do not wait an hour to discover a session never woke. After posting, confirm the
issue key appears in a routing event:

```bash
WS=<log-cyrus-dev customerId>   # az monitor log-analytics workspace show -g rg-cyrus -n log-cyrus-dev --query customerId
az monitor log-analytics query -w $WS --analytics-query "
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(10m)
| where Log_s contains 'Routed session' or Log_s contains 'ignoring non-agent-session' or Log_s contains 'webhook.received'
| project TimeGenerated, Log_s | order by TimeGenerated asc"
```

`Routed session …` or `webhook.received` for your issue means it landed.
`EventRouter ignoring non-agent-session webhook …` at the time you posted means
it did not — repost as an in-thread reply.

The cheaper tell, without Azure: **the issue moves to In Progress and the agent
posts within a few minutes.** Silence for 15 minutes after a comment you expected
to wake a session means it was dropped, not that the agent is thinking.

### When a session is stuck holding an issue

A sandbox that is `running`, `online`, holds a session, and has had nothing
routed to it for hours is **not** reported as stranded — `noteStranded` requires
`stopped`/`absent` and offline, so the failure that blocks work is excluded from
detection by construction. The alert cannot fire for it. The gauge line carries
the evidence (`cyrus.sessions`, `cyrus.online`, `cyrus.last_routed_age_ms`) and
nothing reads it.

Recovery is an in-thread reply, which reaches the sandbox regardless.

Cyrus moves the issue to In Progress on start and to Done when its PR merges.
Parents are **not** moved automatically — see *Closing parents*.

## The per-issue cycle

1. **Implement** — top-level `@cyrus1` comment with the brief.
2. **Review** — when the PR opens, a *new* top-level comment asking for a code
   review of that PR, with instructions to fix every finding. This is the one
   place a top-level comment is worth the risk of being dropped; **verify it
   routed**, and if the implementation session still holds the issue, end that
   session first rather than posting into the void.
3. **Verify** — test-merge into a worktree locally and run the affected suites.
4. **Merge** — squash, then confirm the content actually landed.
5. **Release** — launch whatever the merge unblocked.

Reviews must be a **fresh session**, not a reply to the implementation thread.
The value comes from reading the diff as a stranger; a session that just wrote
the code cannot do that.

Always tell the review session: **do not use `nrp-adversarial-review`** — it
shells out to Codex, which cannot reach its API from the Cyrus sandbox, so the
run stalls or silently falls back.

## Where Cyrus runs

Sandboxes are `Microsoft.App/sandboxGroups` `cyrus-dev-sandbox-grp` in resource
group `rg-cyrus`, subscription **`dit-development`** (not dit-production —
`az group show -n rg-cyrus` fails there and looks like the group does not
exist). The router is `app-cyrus-dev-router`; the Log Analytics workspace is
`log-cyrus-dev`.

A sandbox idle-stops five minutes after its last activity. **An `idle_stopped`
event is not a fault** — a sandbox stopping after a session finishes is correct.
Replying in the thread cold-boots a stopped sandbox.

## What a sandbox cannot do — scope every brief to code only

**A Cyrus sandbox has no access to deployed state or infrastructure.** No `az`
CLI, no cloud credentials, and no outbound network reach — a session that tries
gets `000` from every host and a `403` from the proxy on anything it can reach
at all. It cannot read a container app's environment, query Log Analytics, list
a Key Vault, enumerate a role assignment, reach a deployed API, or download its
own CI artifacts (the results storage account returns `403`).

So **the division of labour is not negotiable**: sandboxes write and test code;
**the orchestrator runs every infrastructure command.** Give a session the
repository and the reasoning, and keep the measurement yourself.

### Why this matters more than it sounds

The failure mode is not a session reporting that it is blocked. It is a session
producing a **confident, plausible, wrong answer** — because the ticket said
something and nothing was available to contradict it. Three shapes recur:

- **A passing suite presented as equivalent to a deployed check.** "1617 passed"
  says nothing about four documents stuck in a real environment.
- **A premise inherited from the issue and never tested.** Issue descriptions
  are the weakest link in this whole loop; the ones that survive contact with a
  running system are the exception.
- **A claim about live configuration derived from the repository.** The
  committed model is what *should* be there. It is routinely not.

The best sessions say plainly that they could not reach the environment. Ask for
that explicitly, and treat it as a good outcome rather than a gap.

### What the orchestrator must carry

Anything whose answer lives outside the repository:

- Reading live container-app env, secrets, revisions, identities and ingress
- Key Vault contents and RBAC role assignments
- Log Analytics and Application Insights queries
- Calling a deployed API, re-seeding an environment, checking a database
- Verifying that a fix actually works in dev or prod after it merges

Do this with subagents on your own machine so it does not eat your context, and
**report the measured result back into the issue thread** so the session is
working from evidence rather than from the ticket.

### Write briefs that say which side of the line the work is on

State it, rather than assuming the session will infer it:

> Do **not** attempt any `az` command or infrastructure change — you have no
> credentials and no outbound reach. Write the code and the reasoning; I will
> run what needs running and report the result back into this thread.

And when a brief carries a fact you measured, say it was measured and that the
rest is an expectation to verify. A session told "this is fact, that is
hypothesis" checks the hypothesis; a session handed a flat assertion builds on
it.

### The measured cost of getting this wrong

A deployment PR reached "all 18 checks green" with a change that would have
taken production offline: the model told a container app to read a Key Vault
secret its managed identity had **no grant on** in prod, so the first reconcile
would have failed to provision a revision. It was invisible from the sandbox and
took one `az role assignment list` from the orchestrator to find. What made it
invisible was a comment in the repository asserting the grant existed — true in
dev, written environment-agnostically, false in prod.

**The repository cannot tell you what is deployed. Only the deployment can.**

## Writing review briefs that find things

Every review in a full project run found real defects under a **fully green**
test suite. Generic briefs produce generic reviews. What works:

- **State the property under attack, not the feature.** "Prove no artefact of
  the source's storage location survives into the target" beats "review the copy
  logic".
- **Name what you expect to be wrong, and say so.** Being contradicted with
  evidence is a good outcome; several times the expected finding was absent and
  something worse was present.
- **Carry forward the previous review's findings by name.** Defects recur across
  issues, and a session that knows the specific shape finds it faster.
- **Ask for negative results.** "Attacked and could not make land" is as useful
  as a finding, and prevents a review inventing something to justify itself.
- **Ask for incremental output.** Post each finding as it is confirmed, push
  fixes in small commits, and push a rebase before starting the review. A
  session that dies mid-pass then costs minutes, not the whole review.
- **Tell it to treat "the tests pass" as evidence of nothing**, and to verify
  empirically against the built assembly rather than against fixtures written to
  the same reading as the code.

### The recurring defect classes

Cite these by name; they keep recurring:

1. **A documented guarantee outrunning the code.** Found in *every* review.
   `CONTRACTS.md` asserting behaviour that does not exist; tests covering a
   component that was never built and therefore could never fail.
2. **A check that stops looking and then says yes.** A bound reached must be a
   *refusal*, never an acceptance. Produced a percent-decode bypass at four
   rounds, a schema depth that left a field checked against nothing, and an IPv6
   embedding that reached the cloud metadata endpoint.
3. **A declared value is a claim, not a measurement.** Sizes and digests written
   by whoever produced the input. A forged archive header made 96 KiB read as
   352 MiB, behind a limit that turned out to be unreachable anyway.
4. **Vacuous tests.** Seven found in one project. A decoy unreachable by
   construction; a fixture already malformed so the assertion never ran; a probe
   that printed output and asserted nothing; a count across a shared store that a
   neighbour could satisfy. **Ask every session to confirm each new test fails
   when the behaviour it covers is removed.**
5. **A parser reporting content as structure.** A link inside angle brackets, a
   marker inside a fenced block or raw HTML. Found three times.
6. **Test doubles that cannot show the defect.** An in-memory store keyed by a
   tuple cannot demonstrate a containment violation, because it does not model
   how a name joins to a container.

### Cross-PR interactions

The orchestrator sees what no single review sees. When two PRs in flight touch
the same guarantee, **say so explicitly in both briefs**. This found a real bug:
one PR rewrote links inside authored bodies while another guaranteed those
bodies were byte-preserved — neither PR's own tests could have caught it.

## Verifying before merge

**Do not trust GitHub's `mergeable` flag** — it is cached and has reported
MERGEABLE for a branch that conflicted locally. Test-merge in a worktree:

```bash
git fetch origin pull/<N>/head:pr<N>tmp --force
git worktree add -f <scratch>/wt<N> pr<N>tmp
cd <scratch>/wt<N> && git merge origin/main --no-edit
# build and test the affected slice against the merged tree
```

This matters most when a PR's CI ran against an older `main` — its base may
predate merges its own design depends on.

**After merging, confirm the content landed.** A squash has dropped a commit in
this repo before:

```bash
git diff --stat origin/main <pr-head> -- <paths>   # expect empty
```

## Sequencing and conflicts

- **Do not run two issues that edit the same files.** Check what a merged PR
  actually touched, not what its title implies.
- Shared documentation files (`CONTRACTS.md`, `README.md`) collide constantly.
  Tell each session to keep doc edits scoped to the sections it changes.
- When several PRs conflict at once, **merge one and sequence the rest**, giving
  each rebase brief the substance of what landed — not just "rebase". A session
  that knows *why* the conflict exists resolves it correctly; one that does not
  produces a textually clean merge that is semantically wrong.
- Generated files (`sdk.gen.ts`, `types.gen.ts`) must be **regenerated**, never
  hand-merged. Say so every time.

## Closing parents

Parent issues are roll-ups. They do **not** close automatically, and must not be
closed until every child is Done — verify with `list_issues --parentId` rather
than from memory.

**Watch for parents that are under-blocked.** A parent whose real dependencies
are not expressed will surface as ready long before it is. Fix the graph rather
than remembering the exception. Conversely, **do not file follow-up issues as
children of a parent you want to close** — that blocks it on work outside its
delivery scope.

## What to escalate rather than decide

Decide yourself: merge order, rebase sequencing, which issues run in parallel,
whether a finding blocks a merge, whether a flake is a flake.

Escalate to the human:

- **Visual regression approvals** (Argos). A gate waved through by the author is
  not a gate. Tell the session not to self-approve, and get the human's call.
- **Accepted-ADR behaviour** a review disagrees with. Reviews should flag, not
  reinterpret; an ADR change is a separate issue.
- **Anything unverifiable in the sandbox** *and* by you — a currency list that
  cannot be checked against its register without network, for example. Anything
  needing live infrastructure is not an escalation; it is yours to measure.
- **Scope questions**, where meeting a criterion literally would break an
  architectural rule.

## Hold a merge when

- An acceptance criterion is only half met (e.g. a record computed but persisted
  nowhere).
- The change breaks **pre-existing data** and needs a backfill. This has come up
  twice; both times the backfill was the right call, and both times the agent
  proposed a better mechanism than the migration originally asked for.
- The review has not actually reported. Green CI is the entry condition for a
  review, not a substitute for one. **Confirm the review session actually
  started** — a review brief that was dropped on the way to the agent looks
  identical to a review still in progress.

## A session that has gone quiet

Before concluding an agent has stalled, check in this order:

1. **Did your last comment route?** See *Where a comment has to land*. A dropped
   comment is by far the most common cause, and re-posting as an in-thread reply
   fixes it in seconds.
2. **Is the PR head moving?** `gh pr view <N> --json headRefOid,updatedAt`. A
   moving head with no Linear comment is a working session, not a stuck one.
3. **Is CI red for a reason that is not theirs?** A repo-wide breakage on `main`
   fails every PR; do not send an agent chasing it.

Only after those does "restart the session" make sense.

**Never re-run a PR's checks while its session may still be pushing.** The
workflow concurrency group cancels the *new* head's run rather than the stale
one, and the checks then sit at `CANCELLED` looking like a hung build. Let the
push trigger its own run.
