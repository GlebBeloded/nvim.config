## Why

Kind: bug
Depends: tree-diff-cutover

After `tree-diff-cutover` removes neo-tree, the loop still tells agents that "LSP restart and neo-tree renders are async". The advice names a plugin that no longer exists. It still matters, because the project tree and changes panel render asynchronously (git status and watcher updates), so it is reworded rather than dropped.

## Evidence

- `.archon/scripts/context_pack.py:33`: `"- LSP restart and neo-tree renders are async: wait for the end state, not for attachment."`
- The same sentence appears in `.archon/commands/implement.md:59`, `.archon/commands/fix.md:67` and `.archon/commands/explore-bug.md:26`.
- `tests/unit/loop/test_probe.lua:8` pins the sentence (`ASYNC`).
- `openspec/specs/loop/spec.md`, requirement "Probe runs Lua in a test child", and its scenario "Agent prompts and context pack point probes at make probe".
- `tree-diff-cutover` lists this wording as a follow-up (its proposal, Impact; its design, Context).

## What Changes

- Reword to "LSP restart and tree and panel renders are async: wait for the end state, not for attachment." in the three prompts, the context pack and the probe test, and in the loop spec requirement and scenario.
- Grep `.archon/`, `tests/unit/loop/` and `docs/` for any other `neo-tree`, `Neotree` or `neo_tree` mention left after the cutover, and reword or remove each one. A mention inside an archived change stays.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `loop`: "Probe runs Lua in a test child" (wording only).

## Impact

- Files:
  - `.archon/scripts/context_pack.py`
  - `.archon/commands/{implement,fix,explore-bug}.md`
  - `tests/unit/loop/test_probe.lua`
  - any other leftover found by the grep
- Tests: `tests/unit/loop/test_probe.lua` asserts the new sentence in all four places.
- Plugins: none. Core keymaps: none.
- `file-tree: Focus returns false without neo-tree` still holds: this change edits no Lua, only loop prompts, the context pack and their test. It runs after `tree-diff-cutover`, which owns that scenario.
- `file-tree: Focus moves to neo-tree` still holds for the same reason.
- Out of scope: the behaviour of `make probe`.

## Decision (user, 2026-10-17)

- "add fixes to that in the loop too: … The loop's own spec and prompts still mention neo-tree."

## Agent decisions

- Keep the advice, with a generic subject ("tree and panel renders"), because the new tree and changes panel also update asynchronously.
