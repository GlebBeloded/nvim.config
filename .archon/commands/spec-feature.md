---
description: Propose a feature as an OpenSpec change with renders
---
# Propose the feature

First, load each of these skills before any other step: `openspec-propose`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-propose. Report each skill as it loads. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (new-feature): brainstorm → spec + renders → user picks a render → plan → implement ×task → check → fix → review → judge → ship.
Your step: **spec + renders**. Input: `idea.md`. Output: the change folder with design.md renders, tasks.md (so the plan step is skipped) and the JSON fields. Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Idea: $ARGUMENTS
Brainstorm: $ARTIFACTS_DIR/brainstorm.md
User feedback from the previous design gate (empty on the first pass): $LOOP_PREV.design-gate.output.text

Create or update the change with the `openspec-propose` skill (id `add-<topic>`, or keep the id
already in openspec/changes/ from a previous pass). Follow openspec/config.yaml `rules` and
docs/workflow.md (Design renders). design.md must contain a "Current render" and "Proposed A" and
"Proposed B" (C optional) renders as ```text blocks with captions and `Highlights:` lines, plus a
mermaid diagram when the flow or module wiring changes. State the recommended option.

Stop after the artifacts exist; do not implement. Set `change` to the change id.

tasks.md format (each task one section of at most 5 scenarios, split by requirement; the gate reads the `Scenarios:` line):

```
## 1. <task title>
Scenarios: `<capability>: <scenario title>`
- [ ] 1.1 Write the test `<capability>: <scenario title>` in tests/<layer>/<capability>/test_<x>.lua (or run it, if it exists) and see it fail
- [ ] 1.2 <the smallest code change>
- [ ] 1.3 Run `make test FILE=tests/<layer>/<capability>/test_<x>.lua CASE="<scenario title>"` and see it pass
```
Run `openspec status`
once, at the end. Do not re-read files you just wrote; read files with `nl -ba` once.
