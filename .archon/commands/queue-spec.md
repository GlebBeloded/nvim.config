---
description: Complete the artifacts of a queued change
---
# Complete the queued change

First, load each of these skills before any other step: `openspec-continue-change`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-continue-change. Report each skill as it loads. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **spec** (queued change). Input: the queued proposal. Output: the completed change folder including tasks.md (so the plan step is skipped) and the JSON fields. Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Change: openspec/changes/$INPUTS.change/
Earlier work: $INPUTS.adopted (when it says "adopted", `git log --oneline auto..HEAD` and `git diff auto...HEAD --stat` show what is already done; specify and plan only the rest)

The change is a queue item (for example a finding from a review) and may
only have proposal.md. Read it, find the root cause if it is a bug (systematic-debugging,
no code changes), then complete the missing artifacts with the `openspec-continue-change` skill
until specs, design (only when there is visible UI: Current + Proposed renders) and tasks exist; refresh any counts or lists the queued proposal quotes (e.g. `make trace VERBOSE=1`) instead of trusting them,
following openspec/config.yaml rules. Do not implement. Set `visible_ui` and `architecture` as in
a fix proposal (screen output changes / module layout, load order or plugin wiring changes).

tasks.md format (each task one section of at most 5 scenarios, split by requirement; the gate reads the `Scenarios:` line):

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Write the test `<capability>: <scenario title>` in tests/<layer>/<capability>/test_<x>.lua (or run it, if it exists) and see it fail
- [ ] 1.2 <the smallest code change>
- [ ] 1.3 Run `make test FILE=tests/<layer>/<capability>/test_<x>.lua CASE="<scenario title>"` and see it pass
```
No design.md unless the change alters what is drawn on screen or the module layout. Run `openspec status`
once, at the end. Do not re-read files you just wrote; read files with `nl -ba` once.
