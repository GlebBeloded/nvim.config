## Why
`<A-e>` on a buffer named like a URI (`vscodediff://x`) does not focus the filesystem tree. `smart_toggle_neotree` (`lua/gleb/keymaps.lua`) skips `reveal_file` for `scheme://` names and runs `Neotree focus filesystem`, but neo-tree treats an omitted `reveal` as enabled when `follow_current_file.enabled` is true. Its command then derives `vscodediff://x` as a reveal path outside the cwd and opens a `neo-tree-popup` asking "File not in cwd. Change cwd to vscodediff:? y/n", which takes focus. The test "keymaps: Alt-e on URI buffer focuses filesystem" (`tests/integration/keymaps/test_keymaps.lua`) is `H.xfail` until this is fixed.

Kind: bug

## What Changes
- Focusing the filesystem tree from a `scheme://` buffer explicitly suppresses neo-tree's implied reveal, so it opens on the cwd without a "Change cwd" prompt. Following ordinary files remains enabled.
- Remove `H.xfail` from "keymaps: Alt-e on URI buffer focuses filesystem"; it must pass.

## Capabilities
### Modified Capabilities
None. The spec already describes the intended behaviour (keymaps: "Alt-e on URI buffer focuses filesystem"); `skip_specs: true`.

## Impact
- Code: `lua/gleb/keymaps.lua` and/or `lua/gleb/file_tree/init.lua`; `tests/integration/keymaps/test_keymaps.lua`.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: following real files outside the cwd (the prompt stays for those).
