# Proposal

## Why

Kind: bug

Upgrade rustaceanvim from `88575b98bb9937fb9983ddec5e532b67e75ce677` (v6.9.7) to
`9cb125de42c0256ed1bc1f9ded8d8f0381317a17` (v9.2.1), while keeping Rust Find Usages behavior. The
[upstream range](https://github.com/mrcjkb/rustaceanvim/compare/88575b98bb9937fb9983ddec5e532b67e75ce677...9cb125de42c0256ed1bc1f9ded8d8f0381317a17)
does not break either failing test; the update gate exposed two unrelated timing defects in existing tests.

## Evidence

- `check-update.log` fails `file-tree: Unchanged git status does not redraw the project tree` with
  `unchanged git status did not finish` at `tests/integration/file-tree/test_performance.lua:365` and fails
  `shortcuts: CHECK_LOCK=0 runs make check without the check lock` because the observed holder leave time is
  `1792449845.352` instead of `nil` at `tests/unit/shortcuts/test_sandbox.lua:747`.
- No commit in the changelog breaks either test. The shortcuts suite starts a bare child at
  `tests/unit/shortcuts/test_sandbox.lua:5`, so it never loads rustaceanvim. The file-tree case edits a generated
  non-Rust repository (`tests/integration/file-tree/test_performance.lua:12-43`), while the installed plugin's
  new entry points run only from `ftplugin/rust.lua` and `ftplugin/toml.lua`.
- The shortcuts failure reproduces alone: its holder sleeps for a fixed four seconds
  (`tests/unit/shortcuts/test_sandbox.lua:739`) but the nested `tests/check.sh` run can outlive it, making the
  post-run assertion race elapsed wall time rather than verify lock bypass.
- The file-tree failure does not reproduce alone, which identifies full-suite scheduling as the trigger for its
  one-second git-completion wait rather than a rustaceanvim behavior change.
- `references: Rust usages in production and test code` passes both cases against the installed plugin source at
  `9cb125de42c0256ed1bc1f9ded8d8f0381317a17`. Neovim is v0.12.5, so changelog commit `08ad08c` raising the
  plugin minimum to Neovim 0.12 does not reject this configuration.

## What Changes

- Keep the rustaceanvim dependency upgrade from `88575b98bb9937fb9983ddec5e532b67e75ce677` to
  `9cb125de42c0256ed1bc1f9ded8d8f0381317a17`.
- Make the two existing gate tests deterministic under full-suite load without weakening their lock-bypass or
  no-redraw assertions.
- Preserve Rust Find Usages behavior and its existing assertions. The Neovim configuration needs no plugin API
  adaptation for this range.
- Core keymaps do not change.
- Out of scope: changing Rust UI or keymaps, changing rustaceanvim internals, or relaxing the specified behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `references`: Rust Find Usages behavior remains unchanged on the upgraded rustaceanvim dependency.

## Impact

- Dependency: `rustaceanvim` advances across the two commits above; no plugin is added or removed.
- Test reliability: `tests/unit/shortcuts/test_sandbox.lua` and
  `tests/integration/file-tree/test_performance.lua` require deterministic synchronization.
- Preserved behavior: `references: Rust usages in production and test code`,
  `shortcuts: CHECK_LOCK=0 runs make check without the check lock`, and
  `file-tree: Unchanged git status does not redraw the project tree`.
- No visible UI, architecture, plugin wiring, Neovim configuration, or core keymap change.
