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

Fix exactly these findings and nothing else, smallest change first. A finding about a contract several
units implement (each adapter, caller or plugin integration) is fixed in every unit it applies to, each checked
against its own native API (installed plugin source), not one rule for all. Stay on the listed findings:
never edit the change's proposal.md, .openspec.yaml or spec deltas unless a finding is about them (the
gate lists such edits for the review), or a failing test pins a main-spec scenario this change intentionally
contradicts: then add a MODIFIED delta restating that scenario to the new behaviour and update the test to the new THEN.
Name each new regression test `<capability>: <scenario title>`: put it in the existing case of that scenario, or add a
same-titled scenario (ADDED, or MODIFIED restating a main-spec one) to openspec/changes/$INPUTS.change/specs; never invent a case name
the specs lack, and never fold or rename a case an earlier pass added (add its scenario instead: the gate counts a vanished case as dropped). A trace DUPLICATE (one case name in two test files) is yours to resolve even when an earlier pass made it: keep the name in one file and rename the other copy after a scenario you ADD to the change's delta for it; never record it as inherited.
An edited assertion must still prove its scenario's THEN; replacing a behaviour/callback check with metadata (desc, buffer) is weakening.
A regression test replays the finding's exact trigger through the real entry point (the real mapping or `<CR>`, the real picker, populated data), never a hand-built stand-in. It asserts the observable effect (the buffer, cursor, window or file state after the key), never only which action or desc a key resolves to.
A UI task (a window, float or view) is done only after one headless probe per edge cell: an empty result (also empty after a filter or toggle), a multibyte line, `VimResized` across the layout breakpoint, and its window closed by `:quit`/`:close`; each autocmd it adds is tied to its buffer or torn down on `WinClosed`.
A fix holds on every update path of what it patches (e.g. a plugin re-setting that state on each update), not only the first.
Find the cause before editing. When the cause is not obvious from the log line (a race, state you cannot see), run one
headless probe first (the scratch-file probe rule below) that logs the relevant state, and base the edit on its output.
At most 2 implementation attempts per pass (an edit plus rerunning the failing test): if the second still fails, first save the second attempt (`git add -N -- . ':!tests' && git diff -- . ':!tests' > $ARTIFACTS_DIR/stuck-attempt.diff`, so new files are in it, named in `## Stuck`), then revert
only the non-test edits (`lua/` and other code; keep the new red regression test), write (or replace) `## Stuck` in tasks.md with the probe output and both attempts,
commit the failing test together with tasks.md (the next fix pass or a re-queued run takes it, never the user), and stop. An attempt is a change to production code (`lua/`) or to your hypothesis about the cause; fixing a mechanical error in your own test or harness code (syntax, arity or multiple returns such as `gsub`, a wrong API or key notation) and rerunning is not an attempt, as long as the test's scenario and assertions stay the same. Write `## Stuck` only when the second production attempt fails on an assertion that tests the behaviour; an ordinary bug is fixed, never stuck while an attempt is left. A finding starting `stuck` quotes tasks.md's `## Stuck` section (earlier attempts): it is your first finding, not your only one (fix every other `FAIL in` line of the gate log in the same pass, each counted apart from the stuck one's 2 attempts); solve it yourself (the run hands it to Claude only if you leave it red) by trying a cause they did not (when `$ARTIFACTS_DIR/stuck-attempt.diff` exists, first `git apply` it and start from that attempt instead of redoing it; `git apply -R` it only once your probe shows its approach is wrong), and once its behaviour is green delete the `## Stuck` section in the same commit. Small design and implementation choices the spec and design leave open (a data format detail, a name, which internal API, a default, an ordering) are yours: decide, and record each in one line under `## Agent decisions` in tasks.md (choice and why). Write `## Blocked` only for a choice that changes user-visible behaviour beyond the spec or design, contradicts the spec or a `## Decision`, or is breaking (an exception that narrows a SHALL is such a choice: never an agent decision); it states the question, the options and your recommendation.
Production code (`lua/`) never uses timers or sleeps (`vim.defer_fn`, `vim.uv` timers, `vim.wait`) to win a race with a
plugin's internals unless the proposal's `## Decision` allows it. Do not re-read plugin source the context pack's `## Evidence` covers.
Read only the latest check log, the `full log:` path in the findings (never a `check-*.log` glob):
search it with `rg -n 'FAIL in' <log>` and `rg -n -C 3 '<pattern>' <log>` (at most `-C 3`), not the
whole log. Search code with one specific term per `rg` and a path, never a broad multi-word `rg` over
`lua tests`. Rerun every test file named in a `FAIL in …` line of that log, plus
`tests/integration/<area>` and `tests/screen/<area>` for each area you touched (`make test FILE=… 2>&1 | tail -40`),
and `make e2e CASE="<area>:" 2>&1 | tail -40` when your edit changes what that area draws or records (its e2e cases replay it); never
`make quick` or `make check` (the next gate runs it). Tick any task you finish in tasks.md. Run `make fmt`, then commit
(conventional message) once `make self-check CHANGE=$INPUTS.change` exits 0 (the gate's lint, types and strict validation of the change and of the trial archive; a green `make specs` or `openspec validate --specs` does not count; red only from base or loop tooling, not this change: commit anyway and append a `loop: …` line to `$ARTIFACTS_DIR/loop-notes.md`). If no finding needs a change (the failure does not reproduce), commit nothing and say so: never `git commit --allow-empty`.

Regenerate a reference screenshot (`tests/screenshots/`) only when its cell diff is limited to UI that
a merged or base commit changed; name that commit (short hash and subject) in the commit message.
Any other screenshot diff is a bug to fix, not a reference to update. A regenerated reference of a visible-UI change must
match design.md's Proposed render (layout, borders, alignment, clipping); fix the code until it does, never bless output that differs.

Tests whose assertion is a time bound (readiness, startup budgets): one sample, no retry, no load factor; if over the bound on a loaded host,
rerun the case once and write `## Stuck` if still over. Waits for a condition are different: they may scale with `H.load_factor()`.

When a fix is directly verified, append one concise cause-to-action line to
`$ARTIFACTS_DIR/lesson-candidates.txt`; start it with `loop:` when it is about loop tooling
(for example a false positive of a loop check) or restates a rule of this command: such lessons are dropped.

Never delete, skip or weaken a test or scenario to get green, least of all the red regression test an earlier pass added: fix the code until it passes; if the spec is wrong (it contradicts itself, the code or a `## Decision`), write it in
tasks.md under "## Blocked" with the options and your recommendation, and stop (no user is asked: the unblock step settles it on your recommendation).

If a failure comes from loop tooling (`.archon/`, `tests/trace.lua`, `tests/sandbox/`, the `make check` targets) and not from this change, do not fix it here: append one line `loop: <failure>` to `$ARTIFACTS_DIR/loop-notes.md` (not tasks.md: the judge lists it for the auditor, and it never stops the change; `<failure>` quotes the failing log line verbatim, never restating its numbers) and go on with the change.

Ad-hoc headless runs: write the probe to a scratch file and run `make probe SCRIPT=$ARTIFACTS_DIR/probe.lua` (the tests' full-config child and sandbox, prints its output and return values, non-zero on error, `PROBE_TIMEOUT` ms); do not hand-build rtp or XDG dirs. LSP restart and tree and panel renders are async: wait for the end state, not for attachment. Visual marks need `exe "normal! V2j\<Esc>"` or `nvim_buf_set_mark`.
Never load the host to reproduce a flake (no `yes`/stress loops, no SIGSTOP tricks): other runs share this machine. A gate log's `FAIL in` line is the RED evidence for a timing flake.
A finding `openspec validate --strict … failed` with "Requirement text is very long (>500 characters)" is about this change's spec delta: shorten that requirement's text there (keep its meaning, move examples and edge cases into scenarios), then run `make self-check CHANGE=<change>` (it runs `spec_trial.py`) until it exits 0. This counts as a fix the finding asks for.
