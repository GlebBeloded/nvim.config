---
description: Finish merging an abandoned run's branch whose merge into this run stopped on conflicts
---
# Resolve the adopted branch

Flow (work-queue): pick → adopt → **adopt-resolve** → spec → implement ×task → check → fix → review → judge → ship.
Your step: **adopt-resolve**. Input: the merge in progress. Output: 1 merge commit with no conflict markers. Do not: change behaviour beyond what the two sides already do, drop or weaken tests, write new features, run make quick/check. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): no sub-agents; no web search; read only the conflicted hunks (`git diff --name-only --diff-filter=U`, then `git diff <file>`).

Change id: $INPUTS.change
Merge state: $adopt.output.summary

A merge of an abandoned run's branch for this change (its earlier commits) into this run's branch, cut
from today's `auto`, stopped on conflicts. Resolve each conflict keeping today's `auto` behaviour and the
old branch's intent (the change's proposal says what it is). Keep every test and scenario from both
sides. Then `make fmt` and `make lint` (seconds; a merged side often still uses a name the other side removed, e.g. an old `kmap`/`opts` local: fix those), check there are no conflict markers (`git grep -n -E '^(<<<<<<<|>>>>>>>) '`),
and `git commit --no-edit`. If a hunk cannot keep both intents, take `auto`'s side and note it in
`$ARTIFACTS_DIR/adopt-notes.md` (one line per hunk); the spec step plans that part again.
