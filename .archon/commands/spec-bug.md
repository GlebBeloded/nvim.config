---
description: Turn a root cause into an OpenSpec change (scenario delta + tasks)
---
# Specify the fix

Bug: $ARGUMENTS
Root cause: $ARTIFACTS_DIR/root-cause.md

If the bug input is an existing change id under openspec/changes/, update that change (skill
`openspec-continue-change`). Otherwise create one with the `openspec-propose` skill, id `fix-<topic>`
(kebab-case). Follow openspec/config.yaml rules:
- spec delta: MODIFIED (the spec describes the buggy behaviour) or ADDED scenario that describes the
  correct behaviour, verifiable in a headless child Neovim. Never remove or weaken a scenario.
- proposal: plugin dependency change? core keymap change? out of scope.
- design.md only when there is visible UI (then Current + Proposed renders) or a structural change.
- tasks.md: each task names its scenario titles; its first step is the failing test
  "<capability>: <scenario title>".

Stop after the artifacts exist; do not implement. Set `change` to the change id, `visible_ui` to
true when the change alters what is drawn on screen, `architecture` to true when it changes module
layout, load order or plugin wiring (docs/architecture/).
