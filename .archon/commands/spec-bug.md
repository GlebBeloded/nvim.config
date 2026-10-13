---
description: Turn a root cause into an OpenSpec change (scenario delta + tasks)
---
# Specify the fix

First, load each of these skills before any other step: `openspec-propose`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-propose. Report each skill as it loads. If one does not
load, stop and report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **spec**. Input: `root-cause.md`. Output: the change folder (proposal + spec delta) and the JSON fields. Do not: write tests, code or tasks.md. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Bug: $ARGUMENTS
Root cause: $ARTIFACTS_DIR/root-cause.md

If the bug input is an existing change id under openspec/changes/, update that change (skill
openspec continue-change). Otherwise create one with the `openspec-propose` skill, id `fix-<topic>`
(kebab-case). Follow openspec/config.yaml rules:
- spec delta: MODIFIED (the spec describes the buggy behaviour) or ADDED scenario that describes the
  correct behaviour, verifiable in a headless child Neovim. Never remove or weaken a scenario.
- proposal: plugin dependency change? core keymap change? out of scope.
- design.md only when there is visible UI (then Current + Proposed renders) or a structural change.
- tasks.md: each task names its scenario titles; its first step is the failing test
  "<capability>: <scenario title>".

Stop after the artifacts exist; do not implement. Set `change` to the change id, `visible_ui` to
true when the change alters what is drawn on screen, `architecture` to true when it changes module
layout, load order or plugin wiring (docs/architecture.md).
