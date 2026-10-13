---
description: Find the root cause of a reported bug (no fixes)
argument-hint: <bug description or openspec change id>
---
# Explore the bug

First, load each of these skills before any other step: `superpowers:systematic-debugging`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$superpowers:systematic-debugging. Report each skill as it loads. If one does not load, stop and
report the error naming it.

Bug: $ARGUMENTS

Use the `superpowers:systematic-debugging` skill (phase 1-3 only: reproduce, trace, root cause).
Context: docs/CLAUDE.md, docs/architecture.md, docs/testing.md, the capability spec in
openspec/specs/<capability>/spec.md and the queued changes in openspec/changes/. If the input is a change id, read
openspec/changes/<id>/ first.

Reproduce in a headless child Neovim where possible (`make test CASE=…`, or a throwaway mini.test
case you delete afterwards). Do not change code, specs or tests.

Write `$ARTIFACTS_DIR/root-cause.md`: symptom, reproduction, root cause with file:line evidence,
affected capability, and the correct behaviour as a WHEN/THEN sentence. Drop anything you could not
prove. If the bug cannot be reproduced or the input is ambiguous, say so in the file and stop.
