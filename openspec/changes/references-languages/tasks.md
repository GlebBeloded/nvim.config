## 1. Fixtures
Scenarios: `references: Lua usages in production and spec files`, `references: Python usages in production and test files`, `references: TypeScript usages in production and test files`, `references: Rust usages in production and test code`, `references: Bash usages in production and test scripts`, `references: Terraform variable usages`
- [x] 1.1 Add the `luaproj`, `pyproj`, `tsproj`, `rustproj`, `bashproj` and `tfproj` fixtures to `tests/fixtures/build.sh`, as listed in design.md, each with a manifest of usage locations. Verify they build: `cargo check` for rustproj, `node --check` / `tsc --noEmit` when available for tsproj, `python3 -m py_compile` for pyproj.

## 2. De-duplicate across clients
Scenarios: `references: Two attached clients list each usage once`
- [x] 2.1 Write the scenario in tests/unit/references/test_request.lua against the pure merge function, and see it fail if `references-view` did not already cover it
- [x] 2.2 Make the merge de-duplicate by uri and range, and ask only clients that advertise `referencesProvider`. Run the file and see it pass.

## 3. One end-to-end case per language
Scenarios: `references: Lua usages in production and spec files`, `references: Python usages in production and test files`, `references: TypeScript usages in production and test files`, `references: Rust usages in production and test code`, `references: Bash usages in production and test scripts`, `references: Terraform variable usages`
- [ ] 3.1 Write the six cases in tests/integration/references/test_languages.lua (fixture copy, wait for the client using the readiness helpers, `gr`, read the tree rows). A missing server or toolchain is a reported skip. See them fail.
- [ ] 3.2 Fix what each case exposes in `request.lua` (server-specific handling) or `scope.lua` (pattern gaps), and log each fix under `## Agent decisions`
- [ ] 3.3 Run `make test FILE=tests/integration/references/test_languages.lua` and see every case pass or skip with a reason, then `make check`

## Agent decisions

- Generate each manifest from the fixture source so its line and byte-column locations cannot drift from edits.
- Use JavaScript-compatible TypeScript syntax so `node --check` remains a valid fallback when `tsc` is unavailable.
- Preserve the first client response for duplicate URI/range locations so merge order and offset encoding stay deterministic.

## Blocked

- Question: may task 3 fix the completed fixtures and LSP configuration, although 3.2 limits fixes to `request.lua` and `scope.lua`? The TypeScript fixture has no ESLint config, so nvim-lspconfig deliberately does not attach eslint; bashls receives the configured root-only `*@(.sh|.inc|.bash|.command)` glob and returns zero references for the fixture's nested scripts. Options: (1) allow an ESLint config in `tsproj` and configure bashls with its recursive upstream glob, or (2) weaken the scenarios by not requiring eslint attachment and by overriding bashls only in the test. Recommendation: option 1, because it tests the real configured behavior and preserves both scenarios without test-only exceptions.
