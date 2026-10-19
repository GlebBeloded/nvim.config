# Proposal

## Why

Kind: bug
Adopt: loop/update-rustaceanvim-20261019-221250

Upgrade rustaceanvim from `88575b98bb9937fb9983ddec5e532b67e75ce677` (v6.9.7) to
`9cb125de42c0256ed1bc1f9ded8d8f0381317a17` (v9.2.1), while keeping Rust Find Usages behavior. The
[upstream range](https://github.com/mrcjkb/rustaceanvim/compare/88575b98bb9937fb9983ddec5e532b67e75ce677...9cb125de42c0256ed1bc1f9ded8d8f0381317a17)
does not break the config: the update gate is false-red because its private test data omits installed Mason tools.

## Evidence

- The gate reports `references: gr classifies every Rust variable usage` and the other TypeScript, Bash,
  Terraform, and Rust reference cases with `rust-analyzer is not executable`, `vtsls is not executable`,
  `bash-language-server is not executable`, or `terraform-ls is not executable`; `lsp: vtsls ready in a small
  project` likewise fails with `vtsls not executable`.
- `.archon/scripts/plugin_update.py:35` copies only `lazy` and `site` into `.tests/xdg/data/nvim`.
  `Makefile:21-22` then points every test at that private data root, and `tests/helpers.lua:48-50` can link
  `mason` only when it exists there.
- The installed plugin source is at the requested new commit. No commit in the changelog causes the failures:
  with `lazy` from the update sandbox and `mason`/`site` from the installed test data, the unchanged cases
  `references: Rust usages in production and test code`, `references: gr classifies Rust struct usages`, and
  `references: Rust struct usages are grouped by usage type` all pass on `9cb125d`.
- The log also contains unrelated failures (`e2e` cannot start its VM, one Git stage race, and one sandbox-lock
  assertion); they are not attributed to rustaceanvim and are outside this change.

## What Changes

- Keep the rustaceanvim dependency upgrade from `88575b98bb9937fb9983ddec5e532b67e75ce677` to
  `9cb125de42c0256ed1bc1f9ded8d8f0381317a17`.
- Adapt the plugin-update test environment so its private dependency snapshot includes installed Mason packages,
  allowing the full gate to test the updated plugin rather than fail before language servers start.
- Preserve the existing Rust Find Usages behavior and assertions without weakening or removing scenarios.
- Core keymaps do not change.
- Out of scope: changing Rust UI or keymaps; changing rustaceanvim internals; weakening language-server tests;
  and fixing the unrelated VM, Git-stage, or sandbox-lock failures in the recorded gate.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loop`: plugin update checks retain the installed dependencies required by the test gate.
- `references`: Rust Find Usages behavior remains unchanged on the upgraded rustaceanvim dependency.

## Impact

- Dependency: `rustaceanvim` is upgraded across the two commits above; no plugin is added or removed.
- Tooling: `.archon/scripts/plugin_update.py` and its loop tests.
- Preserved behavior: `references: Rust usages in production and test code` and its existing integration coverage.
- No visible UI, architecture, plugin wiring, or core keymap change.

## Status

Pinned back in lazy-lock.json: the fix loop did not ship. The unfinished attempt is on branch `loop/update-rustaceanvim-20261019-132103-attempt`. Resume with `make update PLUGIN=rustaceanvim`.

## Rejected run
Run on `loop/update-rustaceanvim-20261019-221250` was rejected by the judge:
- fix loop exhausted with gates still red: tests
- last failures:
  make check is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/785b42fa-2abd-4f04-be5c-f531e84c763a/check-10.log
  ok   lint             0.4 s
  ok   specs            0.5 s
  ok   trace            1.0 s
  ok   types            2.5 s
  ok   chain            6.3 s
  ok   smoke-health    13.9 s
  ok   stack           25.0 s
  FAIL e2e            232.6 s
  FAIL test           272.6 s
  ok   smoke-startup    1.8 s
- note: loop: FAIL in tests/unit/loop/test_drain.lua | loop: Drain gives a re-queued change one more run:
- note: loop: FAIL in tests/unit/loop/test_gate.lua | loop: Gate stops on sandbox infra that fails again on rerun:
- note: loop: FAIL in tests/unit/shortcuts/test_sandbox.lua | shortcuts: CHECK_LOCK=0 runs make check without the check lock:
- note: loop: Error: VM 'nvim-e2e' is not running
- note: loop: sandbox: Lume still reports nvim-e2e unknown while its lume run process is alive, after one restart; giving up (/Users/hlebbeladzed/.cache/nvim-e2e-sandbox/vm.log)
