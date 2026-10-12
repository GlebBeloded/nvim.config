---
description: One TDD build pass over the unchecked tasks of a change
---
# Implement

Change: openspec/changes/$INPUTS.change/ (proposal, specs, design, tasks.md)
Gate result of the previous pass (empty on the first pass):
$LOOP_PREV.gate.output
Verify findings of the previous pass: $LOOP_PREV.verify.output
Review findings of the previous pass: $LOOP_PREV.review.output

Use `openspec-apply-change` for the task flow and `superpowers:test-driven-development` for every
task: write the failing test "<capability>: <scenario title>", see it fail
(`make test CASE="…"`), make it pass with the smallest change, tick the task in tasks.md.
Fix every failure and finding listed above first. Follow docs/architecture/conventions.md.

Never delete, skip or weaken a test or scenario to get green; if the spec is wrong, say so in
tasks.md under "Blocked" and stop. Commit after each task (`git commit`, conventional message).
Stop when every task is ticked and `make test` passes; the gate after you runs `make check`.
