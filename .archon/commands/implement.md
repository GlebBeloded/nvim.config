---
description: Implement the next unchecked task of a change, test first (one task per session)
---
# Implement one task

First, load each of these skills before any other step: `superpowers:test-driven-development`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$test-driven-development. Report each skill as it loads. If one does not load, stop and
report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **implement** (one task, or all tasks of a small change). Input: `context.md` (Next task). Output: 1 commit: the task's test and code, its boxes ticked. Do not: start a task the pack does not list, run make quick/check, edit specs, review. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Read `$ARTIFACTS_DIR/context.md` first: it holds the `## Loop lessons` section of `docs/workflow.md`,
the next task, the root cause's `## Evidence`, the change artifacts and the files tasks.md names. Open other files only when the task
needs them; do not survey the repo, and do not re-read plugin source the Evidence already covers (read a cited range only to edit near it).
Production code (`lua/`) never uses timers or sleeps to win a race with a plugin's internals unless the proposal's `## Decision` allows it.
Find the cause before editing code. When it is not obvious (a race, state you cannot see), run one headless probe first
(the scratch-file probe rule below) that logs the relevant state, and base the edit on its output. At most 2 implementation
attempts per task (an edit plus rerunning its test): if the second still fails, revert only the non-test edits (`lua/` and
other code; keep the new red test), write `## Blocked` in tasks.md with the probe output and both attempts, commit the failing
test together with tasks.md (a blocked change never ships), and stop. An attempt is a change to production code (`lua/`) or to your hypothesis about the cause; fixing a mechanical error in your own test or harness code (syntax, arity or multiple returns such as `gsub`, a wrong API or key notation) and rerunning is not an attempt, as long as the test's scenario and assertions stay the same. Block only when the second production attempt fails on an assertion that tests the behaviour.

Change: openspec/changes/$INPUTS.change/ (the pack quotes proposal, specs, design and tasks.md)

Do the task(s) under "Next task" in the pack (a small change lists all of its tasks there), then stop. Per task: write the failing test "<capability>:
<scenario title>", see it fail, make it pass with the smallest change, tick that task's checkboxes (including an item that only runs that task's test, once it passes) in
tasks.md, run `make fmt`, commit with `git add -A <touched files> openspec/changes/$INPUTS.change` (conventional message), once. Run only that test:
`make test FILE=tests/<layer>/<capability>/test_x.lua CASE="…" 2>&1 | tail -40`. Never run
`make quick` or `make check` (the gate after the task loop runs it once). Keep tool output short: read
file ranges, not whole files; no full logs. Follow the conventions in docs/architecture.md.

When this task corrects a failure from the previous pass (pack section "Last gate failures") and the
correction is directly verified, append one concise cause-to-action line to
`$ARTIFACTS_DIR/lesson-candidates.txt` (start it with `loop:` when it is about loop tooling: such lessons are dropped); otherwise do not write a candidate.

Never delete, skip or weaken a test or scenario to get green; if the spec is wrong, write it in
tasks.md under "## Blocked" and stop.

If a failure comes from loop tooling (`.archon/`, `tests/trace.lua`, `tests/sandbox/`, the `make check` targets) and not from this change, do not fix it here: append one line `loop: <failure>` to `$ARTIFACTS_DIR/loop-notes.md` (not tasks.md: the judge lists it for the auditor, and it never stops the change; `<failure>` quotes the failing log line verbatim, never restating its numbers) and go on with the change.

Ad-hoc headless runs: write the probe to a scratch file and run `make probe SCRIPT=$ARTIFACTS_DIR/probe.lua` (the tests' full-config child and sandbox, prints its output and return values, non-zero on error, `PROBE_TIMEOUT` ms); do not hand-build rtp or XDG dirs. LSP restart and neo-tree renders are async: wait for the end state, not for attachment. Visual marks need `exe "normal! V2j\<Esc>"` or `nvim_buf_set_mark`.
Timing flakes: the gate log's `FAIL in` line counts as "see it fail"; try to reproduce at most once with a normal run, and never load the host (no `yes`/stress loops, no SIGSTOP): other runs share this machine.
