## Why
`<A-e>` on a buffer named like a URI (`vscodediff://x`) does not focus the filesystem tree. `smart_toggle_neotree` (`lua/gleb/keymaps.lua`) skips `reveal_file` for `scheme://` names and runs `Neotree focus filesystem`, but `follow_current_file = { enabled = true }` (`lua/gleb/file_tree/init.lua`) still tries to reveal the current buffer: neo-tree opens a `neo-tree-popup` asking "File not in cwd. Change cwd to vscodediff:? y/n", which takes focus. The test "keymaps: Alt-e on URI buffer focuses filesystem" (`tests/integration/keymaps/test_keymaps.lua`) is `H.xfail` until this is fixed.

Kind: bug

## What Changes
- Focusing the filesystem tree from a `scheme://` buffer opens it on the cwd without a reveal or a "Change cwd" prompt (e.g. focus from a buffer neo-tree does not follow, or skip `follow_current_file` for non-file buffers).
- Remove `H.xfail` from "keymaps: Alt-e on URI buffer focuses filesystem"; it must pass.

## Capabilities
### Modified Capabilities
None. The spec already describes the intended behaviour (keymaps: "Alt-e on URI buffer focuses filesystem"); `skip_specs: true`.

## Impact
- Code: `lua/gleb/keymaps.lua` and/or `lua/gleb/file_tree/init.lua`; `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: following real files outside the cwd (the prompt stays for those).
