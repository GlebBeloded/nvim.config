## Why

Kind: bug
Depends: fix-treesitter-site-links

The startup repair of dangling `site/queries` links raises an error when the directory is not writable:
`lua/gleb/treesitter/repair.lua` wraps `vim.uv.fs_unlink` and `vim.uv.fs_symlink` in `assert` during startup, so a
read-only or permission-denied `site/queries` makes every Neovim start fail with a Lua error.

## Evidence

- lua/gleb/treesitter/repair.lua:52-53 (`assert(vim.uv.fs_unlink(...))`, `assert(vim.uv.fs_symlink(...))`), run from
  the treesitter setup on start (review minor of run fix-treesitter-site-links)

## What Changes

- A link the repair cannot replace is reported once with `vim.notify(..., WARN)` naming the path and the error;
  startup continues and the other links are still repaired.
- A test makes the queries directory read-only, starts the config, and asserts no error and one warning.

## Impact

- lua/gleb/treesitter/repair.lua
- tests/unit/languages/test_site_repair.lua
