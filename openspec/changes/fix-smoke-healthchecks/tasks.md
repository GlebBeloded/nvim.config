# Tasks

**Goal:** `make smoke-health` checks `lazy` and `neo-tree` with no exclude/ignore and reports no ERROR; the `neotest-golang` exclude points at the upstream bug.

**Spec:** none (skip_specs; smoke tooling). `design.md` (Decisions).

## Global Constraints

- No mini.test case: the change modifies no capability, so there is no `<capability>: <scenario title>` to name one after, and an invented name is an orphan that fails `make trace` (docs/testing.md, Naming rule). The layer is Smoke (docs/testing.md): each task's failing test is `make smoke-health` with its exclude/ignore entry removed first.
- No test deleted or weakened; `HEALTH_EXCLUDE` only shrinks.
- LuaCATS types on new functions; small named functions.

## Review Focus

- No plugin code patched; fixes are config only.
- neo-tree `buffers` stays out of `sources` (source cycle unchanged).
- No `lazy-lock.json` change (upstream has no fix for either plugin, see design.md).

---

## 1. lazy luarocks

Scenarios: none (Smoke layer: no `ERROR` in `:checkhealth`)

**Files:** `tests/smoke/run.lua`, `lua/gleb/plugins/init.lua`

- [x] 1.1 **Failing test.** Remove the `hererocks` pattern from `HEALTH_IGNORE`; `make smoke-health` → FAIL (`lazy ... luarocks} not installed`).
- [x] 1.2 **Implement** `rocks = { enabled = false }` in the lazy setup table. `HEALTH_IGNORE` is now empty and only used by `ignored()`: remove both and the filter that calls `ignored()` (design.md, Decision 1). `make smoke-health` → no lazy ERROR.
- [x] 1.3 **Commit** `fix(plugins): disable lazy luarocks support`.

## 2. neo-tree buffers renderers

Scenarios: none (Smoke layer: no `ERROR` in `:checkhealth`)

**Files:** `tests/smoke/run.lua`, `lua/gleb/file_tree/init.lua`

- [x] 2.1 **Failing test.** Drop `neo-tree` from `HEALTH_EXCLUDE`; `make smoke-health` → FAIL (`config.buffers.renderers: expected ?, got nil`).
- [x] 2.2 **Implement** `buffers = { renderers = {} }` in `neo_tree.setup` with a one-line comment (neo-tree's health check validates `buffers` even when it is not in `sources`). `make smoke-health` → no neo-tree ERROR; `make check` green (file-tree tests, screenshots).
- [x] 2.3 **Commit** `fix(file_tree): satisfy neo-tree buffers healthcheck`.

## 3. neotest-golang exclude

Scenarios: none (Smoke layer tooling)

**Files:** `tests/smoke/run.lua`

- [x] 3.1 **Confirm.** Drop `neotest-golang` from `HEALTH_EXCLUDE`; `make smoke-health` → FAIL with only `testify/namespace` and `testify/test_method` (no other neotest-golang ERROR). Restore the entry.
- [x] 3.2 **Document** the entry: stale testify query paths in upstream `health.lua` since https://github.com/fredrikaverpil/neotest-golang/pull/563; remove when fixed upstream. Rewrite the `HEALTH_EXCLUDE` doc comment (external tools plus this upstream bug, no reference to this change).
- [x] 3.3 **Commit** `chore(smoke): document neotest-golang health exclude`.

## 4. Gate

- [x] 4.1 `make smoke-health` green with `HEALTH_EXCLUDE` = external-tool checks + `neotest-golang` only, `HEALTH_IGNORE` gone.
- [x] 4.2 `make check` green.
