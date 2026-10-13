# Design

## Context

See proposal.md - Why. Mode `v` mappings apply to both Visual and Select modes, while mode `x` is
Visual-only. The source branch already contains the intended `x`-only mapping implementation and its
integration coverage. Current `auto` independently fixed `Stack:focused_pane()` with a load-scaled
`retry_cli` path that must remain intact.

There is no visible UI change: Visual-mode behavior is preserved, while Select mode stops inheriting
editing-helper mappings.

## Goals / Non-Goals

**Goals:**

- Define each Visual helper once in `x` mode.
- Port the proven source-branch behavior and tests without regressing current `auto`.
- Exercise Select mode through a key sequence that is available in the full config.

**Non-Goals:**

- Remapping or disabling mini.diff's `gh` mapping.
- Changing any Visual-mode right-hand side.
- Preserving the unnamed register during built-in Select-mode typing.
- Replacing `auto`'s stack CLI retry design.

## Decisions

- **Use `x` instead of `v`:** `x` scopes helpers to Visual mode, so printable keys retain built-in
  Select-mode behavior. Keeping `v` plus matching `sunmap` calls would duplicate each key definition.
- **Drop the Select-only move variants:** the `:m .+1<CR>==` and `:m .-2<CR>==` mappings survive only in
  Select mode today. The existing `x` mappings remain the single Visual-mode implementation.
- **Enter Select mode with `v` then `<C-g>` in the regression test:** mini.diff maps normal-mode `gh`
  to apply hunks. `v` followed by `<C-g>` reaches the same charwise Select mode without changing plugin
  mappings. The test continues to assert `par baz` and Insert mode.
- **Port focused hunks from `loop/fix-20261013-120359`:** use the branch's keymap and integration-test
  work as the reference, but retain current `auto` for `tests/shortcuts/stack.lua`. In particular,
  `Stack:focused_pane()` continues through `query_focused_pane()` and `retry_cli`.
- **Fill the unnamed register by yanking in the test:** `clipboard=unnamedplus` makes direct `setreg`
  setup misleading; yanking matches the existing paste regression test.

## Risks / Trade-offs

- [Select-mode `<A-j>`/`<A-k>` line moves are removed] → Keep their established Visual-mode `x`
  mappings and cover them with the existing integration scenarios.
- [Porting an older branch could overwrite newer test infrastructure] → Limit the port to reviewed
  keymap/spec/test hunks and verify `tests/shortcuts/stack.lua` matches `auto`.
- [The scenario accidentally exercises mini.diff instead of Select mode] → Use `v`, `<C-g>`, `p` and
  assert both the resulting line and Insert mode.
