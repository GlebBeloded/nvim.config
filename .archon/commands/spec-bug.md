---
description: Turn a root cause into an OpenSpec change (scenario delta + tasks)
---
# Specify the fix

First, load each of these skills before any other step: `openspec-propose`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-propose. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **spec**. Input: `root-cause.md`. Output: the change folder (proposal + spec delta + tasks.md, so the plan step is skipped) and the JSON fields. Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Bug: $ARGUMENTS
Root cause: $ARTIFACTS_DIR/root-cause.md

If the bug input is an existing change id under openspec/changes/, update that change (skill
openspec continue-change). Otherwise create one with the `openspec-propose` skill, id `fix-<topic>`
(kebab-case). Follow openspec/config.yaml rules:
- spec delta: only when the spec is wrong or missing the behaviour: MODIFIED (the spec describes the buggy behaviour) or ADDED scenario that describes the
  correct behaviour, verifiable in a headless child Neovim. Never remove or weaken a scenario.
- proposal: plugin dependency change? core keymap change? out of scope.
- design.md only when there is visible UI (then Current + Proposed renders) or a structural change.
- tasks.md: each task names its scenario titles on a `Scenarios:` line as `<capability>: <scenario title>` (the gate checks those have tests, also when the spec delta is empty); its first step is the failing test
  "<capability>: <scenario title>" (when a test with that name exists: run it and see it fail).
  Checkbox items are agent work only; no items to run `make check`/`make quick` (the gate does it).
Get the artifact instructions in one batch and skip design unless there is visible UI or a structural change; do not re-read files you just wrote. Read the capability spec once (`openspec/specs/<capability>/spec.md`, the requirement's line range); run
`openspec status` once at the end.

Stop after the artifacts exist; do not implement. Set `change` to the change id, `visible_ui` to
true when the change alters what is drawn on screen, `architecture` to true when it changes module
layout, load order or plugin wiring (docs/architecture.md). A bug fix that only makes the screen match what an existing spec scenario already requires is not `visible_ui` (no design.md, no design gate); `visible_ui` means a new or changed look.

tasks.md format (each task one section of at most 5 scenarios, split by requirement; the gate reads the `Scenarios:` line):

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Write the test `<capability>: <scenario title>` in tests/<layer>/<capability>/test_<x>.lua (or run it, if it exists) and see it fail
- [ ] 1.2 <the smallest code change>
- [ ] 1.3 Run `make test FILE=tests/<layer>/<capability>/test_<x>.lua CASE="<scenario title>"` and see it pass
```
No design.md unless the change alters what is drawn on screen (then Current + Proposed renders); a structural change is described in the proposal. Do not run `openspec instructions tasks`; the tasks format is given
above. Run `openspec status` once, at the end. Do not re-read files you just wrote; read files with `nl -ba` once.

Refactor or cleanup (no behaviour change, `skip_specs: true`): tasks name existing scenarios whose tests guard the
code you touch; each task is "run those tests and see them pass, change the code, run them again". Never
invent a scenario name: every name on a `Scenarios:` line must be a `#### Scenario:` in openspec/specs or this change's delta.

Before finishing, when the change has a spec delta: keep each requirement's text (between `### Requirement:` and its first scenario, MODIFIED ones restated in full) under 500 characters, and run `python3 .archon/scripts/spec_trial.py <change>`; fix the delta until it exits 0.
For a timing flake, task 1.1 cites the gate log's `FAIL in` line as the failing evidence; it never asks to reproduce under artificial load.
