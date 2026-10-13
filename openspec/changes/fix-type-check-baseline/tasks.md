# Tasks

**Goal:** `make types` passes with the five `"diagnostics.severity"` downgrades removed from `.luarc.jsonc`.

**Spec:** none (skip_specs; type annotations and narrowing). `design.md` (Context table, Decisions).

## Global Constraints

- No mini.test case: the change modifies no capability, so a `<capability>: <scenario title>` name would be an orphan that fails `make trace` (docs/testing.md, Naming rule). The layer is Static (`make types`): each group's failing test is `make types` after deleting that code's severity line.
- No test deleted or weakened; no `---@diagnostic disable` other than the one in group 5.
- No behaviour change, except the restored failure messages in `tests/unit/loop/test_cleanup.lua`.
- LuaCATS types on new functions; small named functions.

## Review Focus

- Plugin types come from `.tests/deps` at the `lazy-lock.json` commits, not local stand-in classes (rule 5.3).
- Casts only where design.md names them.
- `ensure_timer` edit matches `fix-lsp-progress-stuck-task` (same local-variable form).

---

## 1. Plugin type libraries (undefined-doc-name)

Scenarios: none (Static layer: `make types`)

**Files:** `.luarc.jsonc`, `tests/bootstrap.sh`, `tests/types.sh`, `docs/testing.md`

- [ ] 1.1 **Failing test.** Delete `"undefined-doc-name"` from `"diagnostics.severity"`; `make types` → FAIL (`SessionConfig` at `diff_preview.lua:66`, `LazyPluginSpec` at `plugins.lua:59`).
- [ ] 1.2 **Implement.** `tests/bootstrap.sh`: turn the mini.nvim fetch into one named `fetch_pinned <name> <url> <commit>` function (skip when HEAD already matches; replaces the script-wide early `exit 0`), and call it for lazy.nvim and vscode-diff.nvim with the commits read from `lazy-lock.json` (POSIX `sed`, no new tool). Add both dirs to `workspace.library`; add both HEADs to the `tests/types.sh` cache key. `make deps` twice → second run is a no-op; `make types` → no `undefined-doc-name`. Fix any new hit of the five codes that the resolved plugin types surface; queue a change for any other new Warning. Update the `make deps` and `make types` lines of `docs/testing.md` (deps now include the two plugin type libraries).
- [ ] 1.3 **Commit** `fix(types): load lazy.nvim and vscode-diff types from pinned deps`.

## 2. param-type-mismatch in lua/

Scenarios: none (Static layer: `make types`)

**Files:** `.luarc.jsonc`, `lua/gleb/colors/gruvbox-material/init.lua`, `lua/gleb/colors/gruvbox-material/util/convert.lua`, `lua/gleb/file_tree/diff_preview.lua`, `lua/gleb/plugins/plugins.lua`, `lua/gleb/run/init.lua`

- [x] 2.1 **Failing test.** Delete `"param-type-mismatch"`; `make types` → FAIL with the 28-hit list's param-type-mismatch rows (design.md, Context).
- [x] 2.2 **Implement** `pcall(vim.api.nvim_command, ...)` at `gruvbox-material/init.lua:9`, `diff_preview.lua:87`, `:161`; `convert.lua` annotations (`rgb_to_hsl` returns non-optional `number` 0..1, `hsl_to_rgb` takes `number`); `vim.fn.getcharstr()` at `plugins.lua:343`; `--[[@as string]]` on `finddir` at `run/init.lua:3`. `make types` → no lua/ hit of this code; `make test` green (colors and file-tree screenshots unchanged).
- [x] 2.3 **Commit** `fix(types): narrow param types in lua/`.

## 3. param-type-mismatch in tests/

Scenarios: none (Static layer: `make types`)

**Files:** `tests/render/colorize.lua`, `tests/shortcuts/chain.lua`, `tests/shortcuts/stack.lua`, `tests/e2e/shortcuts/test_e2e.lua`, `tests/unit/loop/test_cleanup.lua`

- [x] 3.1 **Failing test.** With `"param-type-mismatch"` still deleted (2.1), `make types` → FAIL with only the tests/ rows of design.md, Context.
- [x] 3.2 **Implement** a typed helper in `colorize.lua` that maps `vim.NIL` to nil (drops the existing `@as colorize.Hl` cast); `tonumber(code) --[[@as integer]]` in `chain.lua:116`; `Stack.env` typed `table<string, string>` with one commented cast on the constructor; `{ fail_reason = ... }` for every string third argument to `eq` in `test_cleanup.lua`. `make types` → no `param-type-mismatch`.
- [x] 3.3 **Verify** the restored messages: temporarily break one `expect_cleanup_sees_merge` expectation, `make test-unit` shows `run.output` as the failure headline; revert. `make test`, `make chain`, `make stack` green; `make colorize FILE=<an existing design.md>` output unchanged.
- [x] 3.4 **Commit** `fix(types): narrow param types in tests/`.

## 4. deprecated

Scenarios: none (Static layer: `make types`)

**Files:** `lua/gleb/lsp/config/python/typecheck.lua`, `.luarc.jsonc`

- [x] 4.1 **Failing test.** Delete `"deprecated"`; `make types` → FAIL at `typecheck.lua:7` only (`fix-diagnostic-navigation` is archived).
- [x] 4.2 **Implement** `client:stop()`. `make types` → no `deprecated`.
- [x] 4.3 **Commit** `fix(lsp): use client:stop() in PyTypeCheck`.

## 5. duplicate-set-field

Scenarios: none (Static layer: `make types`)

**Files:** `lua/gleb/select/init.lua`, `.luarc.jsonc`

- [x] 5.1 **Failing test.** Delete `"duplicate-set-field"`; `make types` → FAIL at `select/init.lua:13`.
- [x] 5.2 **Implement** `---@diagnostic disable-next-line: duplicate-set-field` above the override, with a one-line reason (intended `vim.ui.select` override). `make types` → no `duplicate-set-field`.
- [x] 5.3 **Commit** `fix(select): mark the vim.ui.select override as intended`.

## 6. need-check-nil

Scenarios: none (Static layer: `make types`)

**Files:** `lua/gleb/statusline/lsp_progress.lua`, `.luarc.jsonc`

- [x] 6.1 **Failing test.** If `fix-lsp-progress-stuck-task` has not landed on `auto`: delete `"need-check-nil"`; `make types` → FAIL at `lsp_progress.lua:75`.
- [x] 6.2 **Implement** a local timer in `ensure_timer` (`local t = assert(uv.new_timer())`, start `t`, assign `timer = t`). `make types` → no `need-check-nil`; statusline unit/integration tests green.
- [x] 6.3 **Commit** `fix(statusline): narrow lsp_progress refresh timer`.

## 7. Gate

- [ ] 7.1 `"diagnostics.severity"` is gone from `.luarc.jsonc` (or empty); `make types` green.
- [ ] 7.2 `make check` green.

## Blocked

- **1.2 / 7.1 wait for `fix-diff-preview-codediff-crash`.** With `.tests/deps/lazy.nvim` and `.tests/deps/vscode-diff.nvim` in `workspace.library` and every severity line removed, `make types` reports exactly one Warning: `diff_preview.lua:67` `missing-fields` (`SessionConfig` needs `original` / `modified`). That is the runtime crash `fix-diff-preview-codediff-crash` already queues (old `original_path` / `modified_path` keys vs the pinned vscode-diff Path refs); fixing it here is a behaviour change outside this change's Non-Goals, and suppressing it would hide a real bug. Done so far: `tests/bootstrap.sh` (`fetch_pinned`, lock-file commits), `tests/types.sh` cache key, `docs/testing.md` deps line (commit `chore(deps): fetch lazy.nvim and vscode-diff type libraries at pinned commits`). Remaining after that change lands on `auto`: add the two dirs to `workspace.library`, delete the `"undefined-doc-name"` line (the last one, so drop `"diagnostics.severity"`), update the `make types` line of `docs/testing.md`, commit 1.3, then 7. Status (pass 3): still not on `auto` (`diff_preview.lua:70` still uses `original_path`); 1.1–1.3 and 7 stay open.
- **3.2 note:** LuaLS does not narrow `hl == vim.NIL` (nor `type(hl) == "table"`), so the existing `@as colorize.Hl` cast moved into the `hl_of` helper (commented) instead of disappearing; call sites have no cast.
