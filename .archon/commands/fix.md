---
description: Fix only the findings of the last check and review (one short session)
---
# Fix

First, load each of these skills before any other step: `superpowers:systematic-debugging`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$systematic-debugging. Report each skill as it loads. If one does not load, stop and
report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **fix**. Input: only the listed findings. Output: 1 commit fixing them. Do not: fix anything unlisted, refactor, run make quick/check. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Read the `## Loop lessons` section in `docs/workflow.md` (also in `$ARTIFACTS_DIR/context.md`) first.

Change: openspec/changes/$INPUTS.change/
Findings of the previous pass (check failures, untested scenarios, hard rules, review):
$LOOP_PREV.verdict.output.feedback

Fix exactly these findings and nothing else, smallest change first. Find the cause before editing;
for a failing test read its output in `$ARTIFACTS_DIR/check-<n>.log`, not the whole log. Rerun only the
affected cases (`make test FILE=… CASE="…" 2>&1 | tail -40`); never `make quick` or `make check`
(the next gate runs it). Tick any task you finish in tasks.md. Commit (conventional message).

When a fix is directly verified, append one concise cause-to-action line to
`$ARTIFACTS_DIR/lesson-candidates.txt`.

Never delete, skip or weaken a test or scenario to get green; if the spec is wrong, write it in
tasks.md under "## Blocked" and stop.

If a failure comes from loop tooling (`.archon/`, `tests/trace.lua`, `tests/sandbox/`, the `make check` targets) and not from this change, do not fix it here: write `## Blocked` with `loop: <failure>` in tasks.md and stop.

Ad-hoc headless runs: write the probe to a scratch file and run `timeout 30 nvim -n --headless -u NONE -l /tmp/probe.lua` (body in `pcall`, `vim.cmd('qa!')` last); never inline `+lua` with shell quoting. Visual marks need `exe "normal! V2j\<Esc>"` or `nvim_buf_set_mark`.
