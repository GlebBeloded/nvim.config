# Tasks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** every server with a readiness scenario answers `documentSymbol` within 1 s of `:edit`.

**Architecture:** a readiness probe in a new integration test measures `:edit` → first non-error `documentSymbol` answer in a full-config child. The test harness links mason's install dir into children so the servers start. lua_ls gets fast by moving `workspace.library` out of the editor `.luarc.jsonc` into a types-only config used by `make types`. In the editor, the existing `folke/lazydev.nvim` spec supplies Neovim types lazily.

**Tech Stack:** Neovim 0.12 `vim.lsp`, mini.test child Neovim, mason.nvim, lazydev.nvim, lua-language-server `--check`.

**Spec:** `specs/lsp/spec.md` (Language server readiness), `design.md` (Decisions 1–6), `proposal.md` `## Decision`.

## Global Constraints

- Bound: `< 1000` ms from `:edit` to the first non-error `textDocument/documentSymbol` answer. Never raise it, never assert the symbol count.
- Measure the warm start: every case first starts and stops the server once in a throwaway child (design.md Decision 4).
- A missing server binary fails the case with the binary's name. It never skips (design.md Decision 5).
- Fixtures are written to a temp dir by the test, not committed. The Go fixture imports only the standard library and one local package, so there is no network (Decision 6).
- `make types` keeps the full library: `$VIMRUNTIME`, `${3rd}/luv/library`, `.tests/deps/mini.nvim` (user Decision 1).
- gopls: the 1 s target covers small modules (fixtures) only. Large modules are out of scope and tracked upstream in golang/go#69523 (user Decision 2).
- Case names: `"lsp: <scenario title>"`, exactly as in `specs/lsp/spec.md`.

## Review Focus

- lua_ls with lazydev active: lazydev may add `$VIMRUNTIME/lua` paths through client settings once `.luarc.jsonc` stops overriding `workspace.library`. That could bring the load cost back. Task 2's case runs with the full config, so lazydev is active. If the case fails only with lazydev enabled, escalate. Do not tune it away by weakening the test.
- Editor still types `vim.*`: hover on `vim.api` in `lua/gleb/lsp/config/init.lua` should resolve to a typed function after the split. Task 2.6 checks this.
- `make types` coverage unchanged: same diagnostics count before and after the split (Task 2.4).
- Timing flake under parallel `make test`: run the cases 5 times in a row under the full `make test` (Tasks 1.5, 2.5). If they flake, raise their `.tests/timings.json` weight, never the bound.
- mason loads lazily: if `vim.lsp.enable` fires before mason prepends `mason/bin` to `PATH`, the server never starts. The missing-binary error message shows this (Task 1.4).

---

## 1. Readiness harness and regression scenarios (gopls, basedpyright, vtsls)

Scenarios: `gopls ready within 1 s in a small module`, `basedpyright ready within 1 s in a small project`, `vtsls ready within 1 s in a small project`

**Files:**
- Create: `tests/integration/lsp/test_readiness.lua`
- Modify: `tests/helpers.lua` (`fresh_state`, header comment)
- Modify: `docs/testing.md` (Isolation section)

**Interfaces** (local to `test_readiness.lua`):
- `write_fixture(files: table<string, string>): string`: writes relative path → content into a fresh `vim.fn.tempname()` dir and returns it.
- `ready_ms(child: test.Child, cwd: string, file: string, server: string): integer`: in a full-config child, `cd cwd`. It fails with `"<cmd[1]> not executable"` when `vim.fn.executable(vim.lsp.config[server].cmd[1]) == 0`. In one `child.lua` call it stores `vim.uv.hrtime()` in a global, then `:edit file`. It waits for `vim.lsp.get_clients({ bufnr = 0, name = server })[1]` and sends `textDocument/documentSymbol`, re-sending on an error answer. It records the elapsed ms in the callback of the first non-error answer and returns it. Poll timeout: 10 s, with the elapsed ms in the failure message.
- `warm(child, cwd, file, server)`: calls `ready_ms` once and discards the result, then `child.start_config()` again for the measured run.
- Produces for Task 2: `ready_ms`, `warm`.

- [x] 1.1 **Failing test.** Write `tests/integration/lsp/test_readiness.lua` with `H.child_set(child, start)` (`start` = `child.start_config()` + `child.wait_very_lazy()`). Add three cases, each `warm(...)` then `MiniTest.expect.equality(ms < 1000, true)` (the message includes `ms`):
  - `"lsp: gopls ready within 1 s in a small module"`: `go.mod` (`module example.com/ready`, `go 1.22`), `greet/greet.go` (`package greet; func Hello() string`), `main.go` (imports `example.com/ready/greet` and `fmt`). `:edit main.go`, server `gopls`.
  - `"lsp: basedpyright ready within 1 s in a small project"`: `pyproject.toml` (`[project]\nname = "ready"`), `ready.py` (one `def hello() -> str`). `:edit ready.py`, server `basedpyright`.
  - `"lsp: vtsls ready within 1 s in a small project"`: `package.json` (`{"name":"ready"}`), `tsconfig.json` (`{"compilerOptions":{"strict":true}}`), `index.ts` (one exported function). `:edit index.ts`, server `vtsls`.
- [x] 1.2 **Run, expect FAIL.** `CASE="ready within" make test-integration` → 3 fails with `"gopls not executable"` (and the same for the other two binaries), because `mason/bin` is missing in the child.
- [x] 1.3 **Implement.** In `fresh_state()` (`tests/helpers.lua`), add a `symlink` of `M.data_dir/mason` → `<dir>/data/nvim/mason`, next to `lazy` and `site`. Update the header comment and `M.data_dir`'s doc line to list `mason/`.
- [x] 1.4 **Run, expect PASS.** `CASE="ready within" make test-integration` → 3 passes. If a case still says "not executable", mason has not prepended `PATH` before `vim.lsp.enable`: escalate rather than hard-coding `PATH` in the test.
- [x] 1.5 **Flake check.** `for i in 1 2 3 4 5; do CASE="ready within" make test || break; done` → 5 green runs under parallel load, bound unchanged.
- [x] 1.6 **Docs.** `docs/testing.md` Isolation: "Only `lazy/` (plugins), `site/` (treesitter parsers) and `mason/` (language servers, tools) are symlinked from `NVIM_TEST_DATA_DIR`".
- [x] 1.7 **Commit.** `git add tests/helpers.lua tests/integration/lsp/test_readiness.lua docs/testing.md && git commit -m "test(lsp): readiness scenarios for gopls, basedpyright, vtsls"`

## 2. lua_ls readiness in this config

Scenarios: `lua_ls ready within 1 s in this config`

**Files:**
- Modify: `tests/integration/lsp/test_readiness.lua`
- Modify: `.luarc.jsonc` (drop `workspace.library`)
- Create: `tests/luarc.types.jsonc`
- Modify: `tests/types.sh` (`--configpath`, cache key, header comment, load-error message)
- Modify: `docs/testing.md` (Static row, `make types` cache line)
- Modify: `proposal.md` (lazydev stars and last commit)

**Interfaces:**
- Consumes: `ready_ms`, `warm` from Task 1.
- Produces: `tests/luarc.types.jsonc`, the `--configpath` of `make types`.

- [ ] 2.1 **Failing test.** Add `"lsp: lua_ls ready within 1 s in this config"` to `test_readiness.lua`: `cwd = H.root`, file `lua/gleb/lsp/config/init.lua`, server `lua_ls`, same `warm` + `< 1000` assertion.
- [ ] 2.2 **Run, expect FAIL.** `CASE="lua_ls ready" make test-integration` → FAIL at about 2800 ms.
- [ ] 2.3 **Implement the split** (design.md Decision 1). `.luarc.jsonc` drops the `workspace.library` line and keeps everything else. `tests/luarc.types.jsonc` is the old `.luarc.jsonc` in full, library included: LuaLS has no `extends`, so the duplication is deliberate. Add a `//` comment that it is the `make types` config. `tests/types.sh`: `--configpath="$PWD/tests/luarc.types.jsonc"`. Add `tests/luarc.types.jsonc` to the `git ls-files` list of the cache key. Name that file in the header comment and in the "failed to load" message. lazydev.nvim stays as it is (`lua/gleb/plugins/plugins.lua:18-27`, `ft = "lua"`, pinned `ff2cbcb` in `lazy-lock.json`): no plugin change.
- [ ] 2.4 **Types gate unchanged.** Before 2.3, record `rm -f .tests/types.ok && make types` output. After 2.3, run it again → green with the same diagnostic summary. Then `touch tests/luarc.types.jsonc && make types` still hits the cache, and editing the file busts it.
- [ ] 2.5 **Run, expect PASS.** `CASE="lua_ls ready" make test-integration` → PASS (full config, so lazydev is active). Flake check as in 1.5 with `CASE="ready within"` (all four). If it fails only because of lazydev's library, escalate (Review Focus 1).
- [ ] 2.6 **Editor types.** In this checkout, run `nvim lua/gleb/lsp/config/init.lua`, wait for lua_ls, then hover `vim.lsp.enable` → a typed signature (lazydev's `$VIMRUNTIME` library). This is a manual check: there is no scenario for it, and an unnamed case would be an orphan in `make trace`.
- [ ] 2.7 **Docs.** `docs/testing.md`: the Static row reads `` `tests/luarc.types.jsonc` (LuaJIT, `vim` global, `$VIMRUNTIME` as library) ``. The cache line names `tests/luarc.types.jsonc` instead of `.luarc.jsonc`. `proposal.md` Impact, Plugins: lazydev.nvim is already in the config. Add about 1.5k stars and a last push on 2026-03-14 (gittrend.io), and re-check them on GitHub if it is reachable.
- [ ] 2.8 **Commit.** `git add .luarc.jsonc tests/luarc.types.jsonc tests/types.sh tests/integration/lsp/test_readiness.lua docs/testing.md openspec/changes/fix-lsp-readiness/proposal.md && git commit -m "fix(lsp): keep LuaLS library out of the editor workspace"`

## 3. Gate

- [ ] 3.1 `make check` green. `make trace` lists the four readiness scenarios as tested.

## Workflow follow-up

- Large-module gopls readiness: out of scope per user Decision 2 (option A). Upstream: golang/go#69523. No change is queued.
