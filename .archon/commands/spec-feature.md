---
description: Propose a feature as an OpenSpec change with renders
---
# Propose the feature

First, load each of these skills before any other step: `openspec-propose`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-propose. Report each skill as it loads. If one does not
load, stop and report the error naming it.

Flow (new-feature): brainstorm → spec + renders → user picks a render → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **spec + renders**. Input: `idea.md`. Output: the change folder with design.md renders and the JSON fields. Do not: write tests, code or tasks.md. Keep output brief.

Idea: $ARGUMENTS
Brainstorm: $ARTIFACTS_DIR/brainstorm.md
User feedback from the previous design gate (empty on the first pass): $LOOP_PREV.design-gate.output.text

Create or update the change with the `openspec-propose` skill (id `add-<topic>`, or keep the id
already in openspec/changes/ from a previous pass). Follow openspec/config.yaml `rules` and
docs/workflow.md (Design renders). design.md must contain a "Current render" and "Proposed A" and
"Proposed B" (C optional) renders as ```text blocks with captions and `Highlights:` lines, plus a
mermaid diagram when the flow or module wiring changes. State the recommended option.

Stop after the artifacts exist; do not implement. Set `change` to the change id.
