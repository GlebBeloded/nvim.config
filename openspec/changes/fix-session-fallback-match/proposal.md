## Why
`key.resolve` falls back to the first saved name that merely ends with the cwd slug (`session/key.lua:27-32`), so cwd `/foo/bar` (slug `%foo%bar`) also matches a session for `/baz/foo/bar` (`...-%baz%foo%bar`). The fallback is "most recent" (`session/init.lua:5`) only because resession's default `load_order = "modification_time"` lists names newest first; this config neither sets nor tests it, and the spec's "first entry" wording hides the dependency.

Kind: bug

## What Changes
- Fallback matches only names of the form `<zellij session>-<pane id>-<cwd slug>`: the slug is the whole tail, preceded by `-<digits>-`, and the zellij-session part contains no `%`.
- Set `load_order = "modification_time"` explicitly in `resession.setup`, so the fallback picks the newest session for the cwd; cover it with a test.

## Capabilities
### Modified Capabilities
- `session`: Session resolution (whole-slug match), Restore on bare startup (newest cwd session wins).

## Impact
- Code: `lua/gleb/session/key.lua`, `lua/gleb/session/init.lua`
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: save guards for `nvim file`, empty sessions and unnamed buffers (fix-session-save-guards); cleaning up old session files.
