## Why
`:'<,'>Gitlink` copies a one-line URL: with lines 3-5 selected, register `+` gets `…#L3-L3` instead of `…#L3-L5` (case `git: Gitlink copies range URL`, `tests/integration/git/test_git.lua`). `lua/gleb/git/gitlink.lua:9-13` only turns the command's range into mode `"v"`; gitlinker.nvim's `buffer.get_range` (installed version) then reads the lines from `getpos("v")` and `getcurpos()`, and once `:` has left visual mode both are the cursor, which the range has moved to its first line. The comment at `gitlink.lua:15-18` documents a hand patch of the plugin's `buffer.lua` that a plugin update drops.

Kind: bug

## What Changes
- `:Gitlink` with a range links exactly the range's lines (`t.line1`..`t.line2`), without patching gitlinker; design picks the mechanism (e.g. set the `'<`/`'>` marks or the cursor/visual positions gitlinker reads before calling it, or switch to a maintained fork such as `linrongbin16/gitlinker.nvim` whose command takes a range).
- The stale hand-patch comment in `gitlink.lua` is removed.
- The xfail on `git: Gitlink copies range URL` is removed.

## Capabilities
### Modified Capabilities
- None: the `git` spec already requires the range URL (scenario "Gitlink copies range URL"); this change makes the code meet it.

## Impact
- Code: `lua/gleb/git/gitlink.lua`, `tests/integration/git/test_git.lua`; possibly `lua/gleb/plugins/plugins.lua` if the plugin is replaced.
- Plugins: none, unless design replaces `ruifm/gitlinker.nvim`.
- Core keymaps: unchanged.
- Out of scope: other gitlinker options (hosts, `print_url`, mappings).
