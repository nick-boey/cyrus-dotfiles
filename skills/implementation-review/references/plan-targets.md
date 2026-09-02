# Plan targets for implementation review

Resolve plan evidence with this precedence:

1. an explicit Linear issue, project, or initiative ID/URL;
2. an unambiguous Linear target linked from the PR or current context;
3. an explicit plan file or document;
4. a clearly delimited plan in the conversation.

For Linear targets, use available authenticated connectors to collect the title, description,
acceptance criteria, and attached Linear documents. The target level defines scope:

- Issue: include its active and completed sub-issues and blocking relations.
- Project: include its normative project documents, issues, and their sub-issues.
- Initiative: include its normative initiative documents, projects, issues, and sub-issues.

Treat active and completed descendants as requirements, cancelled or duplicate descendants as
history, and ambiguous backlog items as scope questions. Explicit scope statements outrank
containment. Include comments or broad project material only when requested. Follow external
documents only when the user identifies them as part of the plan.

Build an evidence manifest identifying everything included, excluded, inaccessible, or summarised.
Traverse the full normative hierarchy. When it cannot fit, retain compact metadata for every
descendant and full content for in-scope, incomplete, blocked, high-priority, or referenced items.
Never silently truncate.

If Linear access is unavailable, use context only when it contains the complete intended plan.
Otherwise mark spec conformance `inconclusive` and identify the missing evidence while continuing
the implementation-defect review.
