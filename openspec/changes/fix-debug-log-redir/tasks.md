# Tasks

Layer: integration (`tests/integration/nvim-debug-log/test_debug_log.lua`, child via
`child.start_bare()`); every case is named `"nvim-debug-log: <scenario title>"`.

## 1. Module API: `setup()` / `stop()`, no side effect on require

Scenarios: `Log directory and file created`, `Require alone does not log`, `captures vim.notify`,
`captures :echo from ex command`, `captures :echom from ex command`, `captures errors`,
`periodic flush works during session`, `Log finalized on exit`, `Setup twice logs once`,
`Stop ends logging`.

- [ ] 1.1 Failing test first: `start()` runs `require("gleb.nvim_debug_log").setup()`; add
  `"nvim-debug-log: Require alone does not log"` (restarts with `child.start_bare()`, only
  requires, `:echom "X"`, `vim.wait(3000)`, asserts `log_file()` is nil),
  `"nvim-debug-log: Setup twice logs once"` (second `setup()`, one `VimLeavePre` autocmd,
  `LOGGED_ONCE` counted once in `log_text()`) and `"nvim-debug-log: Stop ends logging"` (`stop()`,
  `:echom "AFTER_STOP"`, wait 3000 ms, absent from `log_text()`). Verify with
  `CAPS=nvim-debug-log make test-integration` that the existing cases and the three new ones fail.
- [ ] 1.2 Rewrite `lua/gleb/nvim_debug_log/init.lua` as a LuaCATS-typed module `M` (design: Module
  shape): `M.setup()` returns early when started, `M.stop()` stops the timer, deletes augroup
  `gleb_nvim_debug_log` and ends the redirection; `VimLeavePre` in that augroup with
  `{ clear = true }` calls `M.stop()`. Still logs via `:redir` here. Small named functions only.
  Verify every task-1 case passes.
- [ ] 1.3 Change `init.lua:4` to `require("gleb.nvim_debug_log").setup()`, still the first require.
  Verify `make quick` is green and `nvim --headless +'echom "INIT_LOG"' +qa` writes
  `INIT_LOG` to a new `/tmp/nvim/<ts>_<pid>.txt`.

## 2. Log through `'verbosefile'` so other redirections survive

Scenarios: `Other redirection survives a flush`; every task-1 scenario as regression.

- [ ] 2.1 Failing test first: add `"nvim-debug-log: Other redirection survives a flush"`
  (`:redir => g:other`, `:echo "OTHER_REDIR"`, `vim.wait(3000)`, `:echo "AFTER_FLUSH"`,
  `:redir END`, assert `child.g.other` contains both). Verify it fails against the `:redir`
  implementation.
- [ ] 2.2 Switch `setup()`, the flush and `stop()` to `'verbosefile'` (design: Proposed A, Flush
  without side effects): `setup()` sets it to the module's path; the flush runs
  `noautocmd set verbosefile=` then `noautocmd set verbosefile=<path>` only while the option equals
  that path; `stop()` resets it to `""` under the same check. Verify every `nvim-debug-log` case
  passes.
- [ ] 2.3 In `docs/workflow.md:167` (Neovim keys debug step) add that `:verbose map`'s
  `Last set from` line goes to the debug log unless
  `:lua require("gleb.nvim_debug_log").stop()` runs first. Verify by hand in a headless child:
  after `setup()` + `stop()`, `execute("verbose nmap <C-h>")` contains `Last set from`.
- [ ] 2.4 Run `make check`; verify it is green.
