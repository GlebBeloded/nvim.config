## Why

Kind: bug

Opening a Rust file prints `vim.lsp.get_buffers_by_client_id() is deprecated` from
`~/.local/share/nvim/lazy/rustaceanvim/lua/rustaceanvim/server_status.lua:52`. rustaceanvim is pinned at `88575b98`
(v6.9.7, `lazy-lock.json`) and constrained to `version = "^6"` (`lua/gleb/plugins/plugins.lua:240`). Upstream fixed it in
`fe91aad2` ("fix(lsp): update function call that is deprecated in nightly", 2025-11-25), first released in v7.0.0;
`make update PLUGIN=rustaceanvim` stays inside `^6`, so it cannot pick the fix up.

Breaking changes since v6 (release notes): v7.0.0 drops ra-multiplex (lspmux instead), v8.0.0 drops
`.vscode/settings.json` support (codesettings.nvim instead), v9.0.0 drops Neovim 0.11 (this config runs 0.12.5). The
config uses none of them (`check = clippy`, `cargo.allFeatures`). Latest: v9.2.1.

## What Changes

- Change the constraint to `version = "^9"` in `lua/gleb/plugins/plugins.lua`. Leave `lazy-lock.json` to the plugin
  update flow: after this ships, `make update PLUGIN=rustaceanvim` moves the pin inside `^9` and runs the full check.

## Impact

- `lua/gleb/plugins/plugins.lua` (one line).
- The rustaceanvim and Rust references cases keep passing on the current pin; the pin moves in the follow-up `make update`.
