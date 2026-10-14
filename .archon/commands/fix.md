---
description: Fix only the findings of the last check and review (one short session)
---
# Fix

First, load each of these skills before any other step: `superpowers:systematic-debugging` (when
every finding below starts with `hard rule:`, load none: there is nothing to debug). On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$systematic-debugging. Report each skill as it loads. If one does not load, stop and
report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **fix**. Input: only the listed findings. Output: 1 commit fixing them, or none when nothing needs changing (say so: the gate reruns); never an empty commit. Do not: fix anything unlisted, refactor, run make quick/check. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Read the `## Loop lessons` section in `docs/workflow.md` (also in `$ARTIFACTS_DIR/context.md` if it exists) first.

Change: openspec/changes/$INPUTS.change/
Findings of the previous pass (check failures, untested scenarios, hard rules, review):
$LOOP_PREV.verdict.output.feedback

Fix exactly these findings and nothing else, smallest change first. Stay on the listed findings:
never edit the change's proposal.md, .openspec.yaml or spec deltas unless a finding is about them (the
gate lists such edits for the review), or a failing test pins a main-spec scenario this change intentionally
contradicts: then add a MODIFIED delta restating that scenario to the new behaviour and update the test to the new THEN.
An edited assertion must still prove its scenario's THEN; replacing a behaviour/callback check with metadata (desc, buffer) is weakening.
Find the cause before editing. When the cause is not obvious from the log line (a race, state you cannot see), run one
headless probe first (the scratch-file probe rule below) that logs the relevant state, and base the edit on its output.
At most 2 implementation attempts per pass (an edit plus rerunning the failing test): if the second still fails, revert
only the non-test edits (`lua/` and other code; keep the new red regression test), write `## Blocked` in tasks.md with the probe output and both attempts,
commit the failing test together with tasks.md (a blocked change never ships), and stop.
Production code (`lua/`) never uses timers or sleeps (`vim.defer_fn`, `vim.uv` timers, `vim.wait`) to win a race with a
plugin's internals unless the proposal's `## Decision` allows it. Do not re-read plugin source the context pack's `## Evidence` covers.
Read only the latest check log, the `full log:` path in the findings (never a `check-*.log` glob):
search it with `rg -n 'FAIL in' <log>` and `rg -n -C 3 '<pattern>' <log>` (at most `-C 3`), not the
whole log. Search code with one specific term per `rg` and a path, never a broad multi-word `rg` over
`lua tests`. Rerun every test file named in a `FAIL in …` line of that log, plus
`tests/screen/<area>` for each area you touched (`make test FILE=… 2>&1 | tail -40`); never
`make quick` or `make check` (the next gate runs it). Tick any task you finish in tasks.md. Run `make fmt`, then commit
(conventional message). If no finding needs a change (the failure does not reproduce), commit nothing and say so: never `git commit --allow-empty`.

Regenerate a reference screenshot (`tests/screenshots/`) only when its cell diff is limited to UI that
a merged or base commit changed; name that commit (short hash and subject) in the commit message.
Any other screenshot diff is a bug to fix, not a reference to update.

Tests whose assertion is a time bound (readiness, startup budgets): one sample, no retry, no load factor; if over the bound on a loaded host,
rerun the case once and escalate (`## Blocked`) if still over. Waits for a condition are different: they may scale with `H.load_factor()`.

When a fix is directly verified, append one concise cause-to-action line to
`$ARTIFACTS_DIR/lesson-candidates.txt`; start it with `loop:` when it is about loop tooling
(for example a false positive of a loop check) or restates a rule of this command: such lessons are dropped.

Never delete, skip or weaken a test or scenario to get green; if the spec is wrong, write it in
tasks.md under "## Blocked" and stop.

If a failure comes from loop tooling (`.archon/`, `tests/trace.lua`, `tests/sandbox/`, the `make check` targets) and not from this change, do not fix it here: append one line `loop: <failure>` to `$ARTIFACTS_DIR/loop-notes.md` (not tasks.md: the judge lists it for the auditor, and it never stops the change) and go on with the change.

Ad-hoc headless runs: write the probe to a scratch file and run `timeout 30 nvim -n --headless -u NONE -l $ARTIFACTS_DIR/probe.lua` (body in `pcall`, `vim.cmd('qa!')` last); never inline `+lua` with shell quoting. Visual marks need `exe "normal! V2j\<Esc>"` or `nvim_buf_set_mark`.
Never load the host to reproduce a flake (no `yes`/stress loops, no SIGSTOP tricks): other runs share this machine. A gate log's `FAIL in` line is the RED evidence for a timing flake.
