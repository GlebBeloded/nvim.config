---
description: Complete the artifacts of a queued change
---
# Complete the queued change

First, load each of these skills before any other step: `openspec-continue-change`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-continue-change. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **spec** (queued change). Input: the queued proposal. Output: the completed change folder including tasks.md (so the plan step is skipped) and the JSON fields. Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Change: openspec/changes/$INPUTS.change/
Earlier work: $INPUTS.adopted. Only if that is not "nothing to adopt" (it says "adopted" or "conflicts merging"; the adopt-resolve step finished that merge; read `$ARTIFACTS_DIR/adopt-notes.md`, the hunks it gave up, only if it exists; never search for it): `git log --oneline auto..HEAD` and `git diff auto...HEAD --stat` show what is already done; specify and plan only the rest.

The change is a queue item (for example a finding from a review) and may
only have proposal.md. Read it, find the root cause if it is a bug (systematic-debugging,
no code changes), then complete the missing artifacts with the `openspec-continue-change` skill
until specs, design.md (only for visible UI: Current + Proposed renders) and tasks exist; refresh any counts or lists the queued proposal quotes (e.g. `make trace VERBOSE=1`) instead of trusting them,
following openspec/config.yaml rules. If the proposal cites file:line and names the requirement, read only those
ranges (`rg -n 'Requirement:' <spec>`, then that range). Drop main spec paths from the proposal's Impact; the delta
covers them. Do not implement. Set `visible_ui` to true when the change alters what is drawn on screen,
`architecture` to true when it changes module layout, load order or plugin wiring (docs/architecture.md).

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

Before finishing, when the change has a spec delta: keep each requirement's text (between `### Requirement:` and its first scenario, MODIFIED ones restated in full) under 500 characters, and run `python3 .archon/scripts/spec_trial.py <change>`; fix the delta until it exits 0.
For a timing flake, task 1.1 cites the gate log's `FAIL in` line as the failing evidence; it never asks to reproduce under artificial load.
