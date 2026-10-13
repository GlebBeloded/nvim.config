---
description: Implement the next unchecked task of a change, test first (one task per session)
---
# Implement one task

First, load each of these skills before any other step: `superpowers:test-driven-development`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$test-driven-development. Report each skill as it loads. If one does not load, stop and
report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **implement**, one task. Input: `context.md` (Next task). Output: 1 commit: the task's test and code, its boxes ticked. Do not: start another task, run make quick/check, edit specs, review. Keep output brief.

Read `$ARTIFACTS_DIR/context.md` first: it holds the `## Loop lessons` section of `docs/workflow.md`,
the next task, the change artifacts and the files tasks.md names. Open other files only when the task
needs them; do not survey the repo.

Change: openspec/changes/$INPUTS.change/ (the pack quotes proposal, specs, design and tasks.md)

Do only the task under "Next task" in the pack, then stop: write the failing test "<capability>:
<scenario title>", see it fail, make it pass with the smallest change, tick that task's checkboxes in
tasks.md, run `make fmt`, commit (conventional message). Run only that test:
`make test FILE=tests/<layer>/<capability>/test_x.lua CASE="…" 2>&1 | tail -40`. Never run
`make quick` or `make check` (the gate after the task loop runs it once). Keep tool output short: read
file ranges, not whole files; no full logs. Follow the conventions in docs/architecture.md.

When this task corrects a failure from the previous pass (pack section "Last gate failures") and the
correction is directly verified, append one concise cause-to-action line to
`$ARTIFACTS_DIR/lesson-candidates.txt`; otherwise do not write a candidate.

Never delete, skip or weaken a test or scenario to get green; if the spec is wrong, write it in
tasks.md under "## Blocked" and stop.
