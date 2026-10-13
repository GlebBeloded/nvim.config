## Context
See proposal.md. The port changes startup order in `init.lua` (rule: load order, `docs/architecture.md`): leader block, then `nvim_debug_log.setup()`, then `gleb.plugins` (lazy.nvim). The archived `fix-mapleader` design (`openspec/changes/archive/2026-10-13-fix-mapleader/design.md`, arrives with the merge) still governs the chords, shortcut rows and tests; this design only covers how its branch lands on today's `auto`.

## Goals / Non-Goals
Goals: `auto` gets everything `fix-mapleader` approved, nothing from `auto` is lost, and the `init.lua` resolution is pinned by tests.
Non-goals: no visible UI change, so no renders. No rewrite of the branch's commits.

## Decisions
- Proposed A (picked): a real `git merge loop/fix-mapleader` on the change branch, conflicts resolved by union. Keeps the branch's commit history and archived artifacts verbatim, so the archive is the one the user approved.
- Proposed B: cherry-pick the branch commits onto the change branch. Rejected: the archive commit (`87ae8bc`) renames `openspec/changes/fix-mapleader/` and would conflict per commit; more hand resolution, same result.
- Proposed C: re-implement from the archived design. Rejected: discards reviewed tests and commits.
- `init.lua` order: leader first (Decision: before lazy.nvim, "at the top of `init.lua`"), then `require("gleb.nvim_debug_log").setup()` (`auto`'s API since `39e10fb`; a bare `require` no longer logs), then `require("gleb.plugins")`. The leader goes before the debug log because the Decision puts it at the top and neither depends on the other.
- Full-config debug-log scenario lives in `tests/integration/nvim-debug-log/test_debug_log.lua`, using a full-config child like `tests/integration/keymaps/test_keymaps.lua`; the leader-before-debug-log scenario lives next to the branch's leader-before-lazy test in `tests/integration/keymaps/test_keymaps.lua`, wrapping `setup` through `package.preload` the same way.

## Risks / Trade-offs
- [E2E only runs in the sandbox VM] → `make check E2E=1` is the gate; the Cmd+O/I/D/A and fold cases both must pass there.
- [`tests/unit/shortcuts/test_sandbox.lua` "A second sandbox lock waits for the first and says so" flaked once under parallel load, also on `auto`] → out of scope; rerun, and queue a change if it keeps failing.
- [Merge brings 146-commit-old docs edits to `docs/architecture.md`] → it auto-merged; reread the leader notes (load order, rules 3.7/3.8) after the merge.
