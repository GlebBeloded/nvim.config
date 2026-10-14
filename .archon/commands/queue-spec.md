---
description: Complete the artifacts of a queued change
---
# Complete the queued change

First, load each of these skills before any other step: `openspec-continue-change`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-continue-change. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **spec** (queued change). Input: the queued proposal. Output: the completed change folder including tasks.md (so the plan step is skipped); no JSON answer (the classify step reads visible UI from design.md's renders and architecture from proposal.md `## Impact` and tasks.md). Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Change: openspec/changes/$INPUTS.change/
Earlier work: $INPUTS.adopted. Only if that is not "nothing to adopt" (it says "adopted" or "conflicts merging"; the adopt-resolve step finished that merge; read `$ARTIFACTS_DIR/adopt-notes.md`, the hunks it gave up, only if it exists; never search for it): `git log --oneline auto..HEAD` and `git diff auto...HEAD --stat` show what is already done; specify and plan only the rest.

**Fast path, `skip_specs: true`** (check `.openspec.yaml` first; a test-only, refactor or follow-up change). The
work-queue meta step already set `schema: spec-driven-no-design` (no design artifact); visible_ui/architecture
are false for test-only changes: there is no JSON to return and no design.md to write.
Write only tasks.md from the matching template under "Refactor or cleanup" below (plus the `## Impact` line for each pinned
scenario, as below), then run `openspec status --change
$INPUTS.change` once; expected: `[x] proposal`, `[~] specs (skipped: change declares skip_specs)`, `[x] tasks`,
"All planning artifacts complete!". Forbidden on this path: reading `.archon/`, `openspec/config.yaml` or
`openspec/changes/archive/`, running `openspec instructions` (any artifact) or `openspec list`, writing design.md
or spec deltas. If the change needs a spec delta after all, delete `skip_specs` and set `schema: spec-driven` in
`.openspec.yaml`, then follow the full path below (no design.md: it never changes the look).

**Full path** (no `skip_specs`):

The change is a queue item (for example a finding from a review) and may
only have proposal.md. Read it, find the root cause if it is a bug (systematic-debugging,
no code changes), then complete the missing artifacts with the `openspec-continue-change` skill
until specs, design.md (only for visible UI: Current + Proposed renders) and tasks exist; refresh any counts or lists the queued proposal quotes (e.g. one capability's trace: `make -s trace VERBOSE=1 | sed -n '/^<capability> /,/^[^ ]/p'`, never the whole listing) instead of trusting them,
following the `rules:` block of openspec/config.yaml (read only that block: `sed -n '/^rules:/,/^operations:/p' openspec/config.yaml`). Locate cited code with `rg -n <symbol>`, not by the proposal's line numbers (they may be stale).
Read the requirement the proposal names and each pinned scenario below, only those ranges (`rg -n 'Requirement:' <spec>`, then that range).
Pinned scenarios (`pinned.py`: main-spec scenarios naming a symbol this change touches): $INPUTS.pinned. Each gets a MODIFIED delta restated to the new behaviour, or one line in proposal.md `## Impact` naming `<capability>: <scenario>` and saying why it still holds; the spec gate reruns `pinned.py --check`.
A bug's proposal (`Kind: bug`) states its root cause with an `## Evidence` section: a list of `file:line` refs (repo or
installed plugin source) or headless probe output that shows the cause; the context pack hands it to implement and fix.
Drop main spec paths from the proposal's Impact; the delta covers them. Do not implement. `visible_ui` is true when the change alters what is drawn on screen: then, and only then, design.md holds `Current render` / `Proposed render` sections (the classify step reads visible UI from them; drop render sections an adopted design.md no longer needs).
A bug fix that only makes the screen match what an existing spec scenario already requires is not `visible_ui` (no design.md renders, no design gate); `visible_ui` means a new or changed look.
`architecture` is true when the change touches module layout, load order or plugin wiring (docs/architecture.md): name each such file (`lua/gleb/plugins/*`, `init.lua`, `lazy-lock.json`) in proposal.md `## Impact`, which classify reads.

The contract is the user's: never change a number or bound (time, size, count) in a requirement or scenario the proposal or an existing delta states, never REMOVE a requirement to ADD it again, never reword the `## Decision` text, and keep any `## Blocked` section as it is, unless a user `## Decision` in the proposal answers it: then delete that Blocked section and follow the Decision. If the contract cannot be met, write `## Blocked` with the reason in tasks.md and stop (the judge asks the user).

tasks.md format (each task one section of at most 5 scenarios, split by requirement; the gate reads the `Scenarios:` line):

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Write the test `<capability>: <scenario title>` in tests/<layer>/<capability>/test_<x>.lua (or run it, if it exists) and see it fail
- [ ] 1.2 <the smallest code change>
- [ ] 1.3 Run `make test FILE=tests/<layer>/<capability>/test_<x>.lua CASE="<scenario title>"` and see it pass
```
A task never empties a test file: removing a file's last case deletes the file (a hard rule). When a
task moves or merges duplicate cases, keep the copy in the file that would be emptied and drop the other.
No design.md unless the change alters what is drawn on screen (then Current + Proposed renders); a structural change is described in the proposal. Do not run
`openspec list` or `openspec instructions tasks`; the change and tasks format are given above. Run `openspec status`
once, at the end. Do not re-read files you just wrote; read files with `nl -ba` once.

Refactor or cleanup (no behaviour change, `skip_specs: true`): tasks name existing scenarios whose tests guard the
code you touch; each task is "run those tests and see them pass, change the code, run them again". Never
invent a scenario name: every name on a `Scenarios:` line must be a `#### Scenario:` in openspec/specs or this change's delta.
With `skip_specs: true`, read only `rg -n '^#### Scenario:'` of the named spec, no archive examples; visible_ui/architecture are false for test-only changes — don't grep for them. Task template:

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Run `make test FILE=<test file> CASE="<scenario title>"` and see it pass, make the change, run it again and see it pass
```

The refactor template is only for changes that leave every assertion as is. A change that adds or tightens an
assertion (a `Kind: bug` test fix, even with `skip_specs: true`) uses the bug template instead: task 1.1 makes the new
assertion fail once by a temporary fault (inject the bad state in the test, or revert the guarded code locally),
records that failure, then removes the fault:

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Add or tighten the assertion in `<test file>`; with a temporary fault (<the bad state or reverted code>) run `make test FILE=<test file> CASE="<scenario title>"`, see it fail and record the failure, then remove the fault
- [ ] 1.2 Run `make test FILE=<test file> CASE="<scenario title>"` and see it pass
```

Before finishing, when the change has a spec delta: keep each requirement's text (between `### Requirement:` and its first scenario, MODIFIED ones restated in full) under 500 characters, and run `python3 .archon/scripts/spec_trial.py <change>`; fix the delta until it exits 0.
For a timing flake, task 1.1 cites the gate log's `FAIL in` line as the failing evidence: copy the `FAIL in` lines from the proposal; never search `artifacts/runs` or old gate logs. It never asks to reproduce under artificial load.
Never read `openspec/config.yaml` beyond its `rules:` block, or a doc whole. When the proposal already lists the bugs, do not search old branches for them.
