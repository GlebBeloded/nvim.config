# Tasks

**Goal:** Session saves run only for a bare-started Neovim with at least one listed file buffer, and auto-save skips unnamed buffers.

**Spec:** `specs/session/spec.md` (Save on write and exit, Auto-save modified buffers), `design.md` (Decisions).

## Global Constraints

- LuaCATS types on every new function; small named functions, no long anonymous function.
- "Started bare" is captured once at module load, not re-read at save time.
- No test deleted or weakened; existing scenario titles unchanged.

## Review Focus

- `argc(-1)` must be read before `VimEnter`, at `init.lua` load; `:argadd` later must not enable saves.
- File-argument tests pass the file as an absolute path (args resolve against the process cwd, not `--cmd cd`).
- The "unchanged" assertions compare the session file contents (and still `a.txt`), not just existence.
- `child.stop()` triggers `VimLeavePre`; read session files after the stop when the scenario includes quitting.
- The E32 test must reset `v:errmsg` to `""` before typing and wait past the debounce (`AUTOSAVE_WAIT_MS`).

---

## 1. Save guards

Scenarios: "session: nvim with a file argument does not save the session", "session: quitting without file buffers keeps the previous session", "session: quitting saves the session", "session: writing a buffer saves the session"

**Files:** `lua/gleb/session/init.lua`, `tests/integration/session/test_session.lua`

- [x] 1.1 **Failing test.** In `test_session.lua` add:
  - `T["session: nvim with a file argument does not save the session"]`: `local path = save_pane_session("z", "5", "a.txt")`, `child.stop()`, then `local before = vim.fn.readfile(path)` (the stop's `VimLeavePre` save happens before the read); write an absolute `b.txt`, `restart_in_pane("z", "5", { b })`, `child.cmd("write")`, `child.stop()`; `eq(vim.fn.readfile(path), before)` and assert the text contains `a.txt`.
  - `T["session: quitting without file buffers keeps the previous session"]`: same setup and `before` read, `restart_in_pane("z", "5")`, `child.cmd("%bwipeout!")`, `child.stop()`; same two assertions.
  - `T["session: quitting saves the session"]` (no test exists yet): bare start, `edit_file("a.txt")`, build the path `<child stdpath data>/session/<key.session_name()>.json` while the child runs, `child.stop()`; the file exists and lists `a.txt`.
  - Run `make test-integration FILE=tests/integration/session/test_session.lua` → the two guard cases FAIL, "quitting saves the session" and "writing a buffer saves the session" PASS.
- [x] 1.2 **Implement** in `init.lua`: `local started_bare = vim.fn.argc(-1) == 0` at load; `---@return boolean local function has_file_buffer()`; `---@return boolean local function should_save()`; `save` returns early unless `should_save()`; `restore` uses `started_bare`. Update the header comment. Run the same command → all `session:` cases PASS.
- [x] 1.3 **Commit** `fix(session): save only bare sessions with file buffers`.

## 2. Auto-save skips unnamed buffers

Scenarios: "session: unnamed buffer is not auto-written", "session: modified file buffer is auto-written"

**Files:** `lua/gleb/plugins/plugins.lua`, `tests/integration/session/test_session.lua`

- [x] 2.1 **Failing test.** Add `T["session: unnamed buffer is not auto-written"]`: `child.cmd("enew")`, `child.v.errmsg = ""`, `child.type_keys("i", "hello", "<Esc>")`, `vim.uv.sleep(AUTOSAVE_WAIT_MS)`; assert `{ child.bo.modified, child.v.errmsg:find("E32") }` equals `{ true, nil }`. Run `make test-integration FILE=tests/integration/session/test_session.lua CASE="unnamed buffer"` → FAIL (E32).
- [x] 2.2 **Implement** a named `---@param buf integer ---@return boolean local function should_autosave(buf)` in the auto-save spec that also requires `vim.api.nvim_buf_get_name(buf) ~= ""`; pass it as `condition`. Run the same command → PASS, including the existing auto-save cases.
- [x] 2.3 **Commit** `fix(session): auto-save skips unnamed buffers`.

## 3. Gate

- [ ] 3.1 `make check` green; `make trace` reports no orphans for the new scenario titles.
