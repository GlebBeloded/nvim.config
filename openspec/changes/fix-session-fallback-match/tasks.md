# Tasks

**Goal:** The cwd fallback of `key.resolve` matches only `<zellij session>-<pane id>-<cwd slug>` names for the whole cwd slug, and picks the newest one because resession's `load_order = "modification_time"` is pinned.

**Spec:** `specs/session/spec.md` (Session resolution, Restore on bare startup), `design.md` (Decisions).

## Global Constraints

- `key.lua` stays free of plugin dependencies; LuaCATS types on every new function; small named helper, no long anonymous function.
- Suffix comparison is plain string (no pattern built from the slug); the head before `-<slug>` must match `^[^%%]+%-%d+$`.
- No test deleted or weakened; existing scenario titles unchanged.

## Review Focus

- Slugs with pattern-magic characters (`.`, `-`, `%`) must not break matching (`%Users%me%.config%nvim`).
- Zellij session names with dashes (`my-proj-5-<slug>`) still match.
- With cwd `/foo/bar`, `x-9-%baz-1-%foo%bar` (cwd `/baz-1-/foo/bar`) does end with `-%foo%bar`, and its head `x-9-%baz-1` ends in `-<digits>`; it is rejected only because the head contains `%`.
- resession compares `mtime.sec`: the newest-session test sets mtimes seconds apart, never relies on save order.
- `load_order = "filename"` sorts ascending: the older session must have the smaller filename, or the order-sensitivity check proves nothing.
- The newest-session test must not leak `ZELLIJ_*` into the runner env (other cases inherit it).

---

## 1. Whole-slug fallback match

Scenarios: "session: resolve ignores a session for a deeper path with the same tail", "session: resolve falls back to any session for this cwd", "session: resolve returns nil when no session matches the cwd", "session: resolve prefers the exact pane key"

**Files:** `lua/gleb/session/key.lua`, `tests/unit/session/test_key.lua`

- [x] 1.1 **Failing test.** Add `T["session: resolve ignores a session for a deeper path with the same tail"]`: `eq(resolve("blossom-5-" .. cwd_slug(), { "blossom-9-%baz" .. cwd_slug(), "x-9-%baz-1-" .. cwd_slug() }), vim.NIL)` (sessions for `/baz<cwd>` and `/baz-1-<cwd>`). Add to the fallback test a second case with a dashed zellij name (`my-proj-9-<slug>` resolves). Run `make test-unit FILE=tests/unit/session/test_key.lua` → the new case FAILS (returns the `%baz` name).
- [x] 1.2 **Implement** `---@param candidate string ---@param slug string ---@return boolean local function is_cwd_session(candidate, slug)`: false unless `candidate` ends with `"-" .. slug` (plain `vim.endswith`); then the head (`candidate:sub(1, -#slug - 2)`) must match `^[^%%]+%-%d+$`. `M.resolve` uses it. Update the comment above `resolve`. Run `make test-unit` → all `session:` cases PASS.
- [x] 1.3 **Commit** `fix(session): fallback matches the whole cwd slug`.

## 2. Newest cwd session wins

Scenarios: "session: bare nvim restores the newest cwd session"

**Files:** `lua/gleb/session/init.lua`, `tests/integration/session/test_session.lua`

- [x] 2.1 **Failing test.** Add `T["session: bare nvim restores the newest cwd session"]` to `tests/integration/session/test_session.lua`. In the started child (cwd `dir`), save two sessions with `require("resession").save(Key.session_name(), { notify = false })` after setting `vim.env.ZELLIJ_SESSION_NAME`/`ZELLIJ_PANE_ID` in the child: `b` / `7` with buffer `new.txt`, then `a` / `8` with buffer `old.txt` (`%bwipeout!` between saves). The names are picked so `a-8-<slug>` sorts first by filename and `b-7-<slug>` loses a filename sort. Session file: `vim.fs.joinpath(child.fn.stdpath("data"), "session", name .. ".json")`. Set mtimes with `vim.uv.fs_utime` so `b-7` is newer by ≥10 s (e.g. now and now − 60). Restart into the same data dir without `start_config`, which isolates fresh state: set `vim.env.ZELLIJ_SESSION_NAME = "c"` and `vim.env.ZELLIJ_PANE_ID = "9"` in the runner, call `child.restart(vim.list_extend({ "--cmd", "cd " .. dir }, H.config_args()))`, disable `H.DISABLED_PLUGINS` via `child.disable_plugin`, and reset the two runner env vars to `nil` afterwards (including when the test fails, e.g. with `MiniTest.finally`). Assert `child.fn.expand("%:t") == "new.txt"`. The plugin default already gives this order, so the failing step is: temporarily set `load_order = "filename"` in `resession.setup`, run `make test-integration FILE=tests/integration/session/test_session.lua` → FAIL (`old.txt`); revert.
- [x] 2.2 **Implement** `load_order = "modification_time"` in `resession.setup` with a short comment that the cwd fallback relies on newest-first order. Update the `init.lua` header comment to point at it. Run `make test-integration` → PASS.
- [x] 2.3 **Commit** `fix(session): pin newest-first session order`.

## 3. Gate

- [x] 3.1 `make check` green; `make trace` reports no orphans for the new scenario titles.

## 4. Restore scenarios restated by the MODIFIED requirement

Scenarios: "session: bare nvim restores the pane session", "session: bare nvim restores a cwd session after pane id change", "session: nvim with a file argument does not restore"

**Files:** `tests/integration/session/test_session.lua`

- [x] 4.1 **Tests.** Add the three integration cases, reusing `save_pane_session`/`restart_in_pane` (which gains optional extra args for the file argument). The behavior already exists, so they pass on first run; confirm each fails when restore is disabled.
- [x] 4.2 **Commit** `test(session): cover restore on bare startup scenarios`.
