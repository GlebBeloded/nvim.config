## Why
Change `fix-mapleader` was approved and archived on branch `loop/fix-mapleader` (tip `87ae8bc`), but that branch is 146 commits behind `auto` and its merge conflicts in `init.lua`, `openspec/specs/shortcuts/spec.md` and `tests/e2e/shortcuts/test_e2e.lua` (root cause: `auto` changed the same hunks in `39e10fb` debug-log `setup()`, `2ec1cbc`/`21031f1` sandbox lock and load-scaled deadlines, `a242b9c` fold e2e case). On `auto` the leader is still the literal `<D->` set after lazy.nvim, and diffview conflict maps are still `<leader>co/ct/cb/ca`.

The `init.lua` conflict is the risky one: the branch's side has the old bare `require("gleb.nvim_debug_log")`, which since `39e10fb` no longer starts logging. Taking that side would silently disable the debug log, and no scenario catches it: every `nvim-debug-log` scenario calls `setup()` itself, none loads the full config.

Kind: bug

## What Changes
- Merge `loop/fix-mapleader` into the change branch. This brings the archived change `openspec/changes/archive/2026-10-13-fix-mapleader/`, its spec updates (`keymaps`, `git`, `shortcuts`), code (`init.lua`, `lua/gleb/keymaps.lua`, `lua/gleb/git/diffview.lua`), docs (`docs/architecture.md`) and tests. It also moves the live `openspec/changes/fix-mapleader/` from `auto` into the archive.
- Resolve the three conflicts by keeping both sides:
  - `init.lua`: the branch's `vim.g.mapleader = " "` / `vim.g.maplocalleader = "\\"` block first, then `auto`'s `require("gleb.nvim_debug_log").setup()`, then `require("gleb.plugins")`.
  - `openspec/specs/shortcuts/spec.md`: `auto`'s requirements "Concurrent sandbox runs never share the guest" and "Test harness deadlines scale with host load" plus the branch's "Cmd chords reach Neovim as <D-…>", every scenario kept; the Cmd+O/I/D/A table rows and `auto`'s "Known gaps" paragraph (already merged cleanly).
  - `tests/e2e/shortcuts/test_e2e.lua`: `auto`'s fold fixture and case "Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press" (with its closing `end` restored) and the branch's case "Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press"; `auto`'s `OWN_CASE` (Cmd+Q, Cmd+H) and the branch's `CMD_CHORDS` / `CMD_CHORD_RECORDERS`.
- Add a scenario that the full config starts the debug log, and one that the leader is already Space when the debug log starts, so the `init.lua` resolution is pinned.
- Honour the Decision of `fix-mapleader` (user, 2026-10-12): no `<leader>` maps in the config, diffview conflict choices on Cmd+O/I/D/A (`<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`) each proven by e2e in the sandbox VM, `mapleader = " "` at the top of `init.lua` before lazy.nvim as a fallback only, `maplocalleader` stays `\`. The branch implements this; the port must not change it.

## Capabilities
### New Capabilities
None.

### Modified Capabilities
- `nvim-debug-log`: `Per-session log file` gains a scenario that the full config (`init.lua`) starts the log.
- `keymaps`: `Leader keys` takes the archived `fix-mapleader` text (Space / `\`, set in `init.lua` before lazy.nvim) and gains a scenario that the leader is set before the debug log starts.

## Impact
- Code: `init.lua`, `lua/gleb/keymaps.lua`, `lua/gleb/git/diffview.lua` (from the merge); docs: `docs/architecture.md` (from the merge). Tests: `tests/integration/keymaps/test_keymaps.lua`, `tests/integration/git/test_diffview.lua`, `tests/stack/shortcuts/test_stack.lua`, `tests/e2e/shortcuts/test_e2e.lua` (from the merge), `tests/integration/nvim-debug-log/test_debug_log.lua` (new scenario). No change to `terminal/`.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed, as approved in `fix-mapleader`: `<leader>` becomes Space (no config map uses it); diffview conflict choices move from `<leader>co/ct/cb/ca` to Cmd+O/I/D/A.
- Out of scope: any change to the archived `fix-mapleader` artifacts or its Decision; the pre-existing flake in `tests/unit/shortcuts/test_sandbox.lua` ("A second sandbox lock waits for the first and says so", E484 on `lock/owner` under parallel load, seen on `auto` too); the other proposal-only changes that fail `openspec validate --strict`.
