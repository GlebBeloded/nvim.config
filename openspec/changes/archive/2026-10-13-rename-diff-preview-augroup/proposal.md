## Why
Augroup `DiffPreviewFocusGuard` (`lua/gleb/file_tree/diff_preview.lua:27`) breaks rule 4.4 of `docs/architecture.md` (augroups are `gleb_<feature>[_<purpose>]`). The `file-tree` spec pins the name in the scenario "Return clears tab state and focus guard", so `cleanup-convention-targets` (no spec delta) leaves it.

Kind: bug

## What Changes
- Rename the augroup to `gleb_file_tree_focus_guard`.
- `file-tree` spec delta: the scenario that names `DiffPreviewFocusGuard` uses the new name; `tests/integration/file-tree/test_diff_preview.lua` follows.

## Capabilities
### Modified Capabilities
- `file-tree`: augroup name in the "Return clears tab state and focus guard" scenario.

## Impact
- Code: `lua/gleb/file_tree/diff_preview.lua`, `tests/integration/file-tree/test_diff_preview.lua`, `openspec/specs/file-tree/spec.md`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: `99PromptKeymaps` (`rename-ai-prompt-augroup`); other augroup renames (`cleanup-convention-targets`); the codediff crash (`fix-diff-preview-codediff-crash`).
