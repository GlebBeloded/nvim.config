# Tasks

**Goal:** every rule site in proposal.md (minus the Non-Goals in design.md) has no remaining hit, with no
behaviour change: `make check` green, smoke startup within budget.

**Spec:** none (`skip_specs: true`). design.md (Decisions).

## Global Constraints

- No new mini.test case: the change modifies no capability, so a `<capability>: <scenario title>` name
  would be an orphan that fails `make trace` (docs/testing.md, Naming rule). Each group's failing test is
  its Static-layer `rg` check (design.md, "Verification is a grep per rule"); behaviour stays pinned by the
  existing scenarios each group lists as regression guards, which must stay green.
- Line numbers are from `auto` at `f416cd3`. Paths are relative to `lua/gleb/` unless they start with
  `init.lua`, `tests/`, `docs/` or `openspec/`.
- No test deleted or weakened. Small named functions, LuaCATS on new functions (rules 5.1, 7.3).
- No plugin added, removed or upgraded; no core keymap change; no screen output change.
- One commit per group.

## Review Focus

- Group 5: nothing at startup still requires neotest, dap or nvim-surround (else the trigger is a no-op).
- Group 3: `clear = true` on every augroup; `<buffer>`-scoped Vimscript becomes `buffer = event.buf`.
- Group 4: `copilot.lua` keeps `cmd`/`event`, so Copilot never loads before `InsertEnter`.

---

## 0. Sync with `auto`

- [x] 0.1 `git rebase auto` (the branch forked at `ac413b8`; `fix-session-save-guards`,
  `fix-diff-preview-stale-tab`, `fix-type-check-baseline` and others landed since). `make quick` green.

## 1. Module layout (1.2, 1.4, 4.1)

Scenarios: none (Static layer: `rg`). Regression guards: "statusline: copilot glyph hidden before load"
and the rest of `tests/*/statusline/`, "session: bare nvim restores the pane session", "session: no
matching session leaves startup untouched".

**Files:** `init.lua`, `lualine.lua` → `statusline/lualine.lua`, `statusline/init.lua` (new),
`alpha-nvim.lua` → `alpha.lua`, `session/init.lua`, `tests/quick.sh`, `docs/architecture.md`

- [x] 1.1 **Failing test.** `rg -n 'gleb\.lualine|gleb\.alpha-nvim|lualine\.lua\)' init.lua tests/quick.sh`
  and `rg -n '^\s*return \{\}' lua/gleb/session/init.lua` → hits (`init.lua:25,27`, `quick.sh:49`,
  `session/init.lua:13,52`).
- [x] 1.2 **Implement.** `git mv lua/gleb/lualine.lua lua/gleb/statusline/lualine.lua`; new
  `statusline/init.lua` only requires `gleb.statusline.lualine`; `init.lua:27` requires `gleb.statusline`
  (keep the trailing comment); drop the `lua/gleb/lualine.lua)` case from `tests/quick.sh:49` (the folder
  rule covers it); update the module row in `docs/architecture.md`.
- [x] 1.3 **Implement.** `git mv lua/gleb/alpha-nvim.lua lua/gleb/alpha.lua`; update `init.lua:24-25`
  (require and comment), the `session/init.lua:61` comment and `docs/architecture.md:91` (module name; the
  plugin name `alpha-nvim` in `plugins.lua:315` stays).
- [x] 1.4 **Implement.** `session/init.lua:13` becomes a bare `return`; delete `:52`. Confirm
  `rg -n 'require\("gleb\.session"\)' init.lua lua tests` shows no caller using the value.
- [x] 1.5 **Green.** 1.1 checks list nothing; `make test CASE=statusline`, `make test CASE=session`,
  `make smoke` pass. **Commit** `refactor: statusline owns lualine setup, alpha.lua, session returns nothing`.

## 2. Options and naming (1.7, 4.2, 4.3)

Scenarios: none (Static layer: `rg`). Regression guards: all scenarios (`lsp/config` and `select` load at
startup), `make smoke`.

**Files:** `options.lua`, `lsp/config/handlers.lua`, `lsp/config/init.lua`,
`colors/gruvbox-material/init.lua`, `bufferline.lua`, `select/init.lua`, `select/code_action.lua`

- [x] 2.1 **Failing test.** `rg -n 'winborder' lua/gleb/lsp`, `rg -n 'require\("gleb/' lua`,
  `rg -n 'buferFilter|langauge|defaultSelect|codeAction|function \w+:[a-z]+[A-Z]' lua` and
  `rg -n 'set background' lua` → hits.
- [x] 2.2 **Implement.** Move `vim.o.winborder = "rounded"` and its comment from
  `lsp/config/handlers.lua:33-34` to `options.lua`. In `colors/gruvbox-material/init.lua:7` replace
  `vim.cmd([[ set background=dark ]])` with `vim.o.background = "dark"` and a one-line comment: the
  colorscheme owns it and it must precede `:colorscheme`.
- [x] 2.3 **Implement.** Dot require paths at `lsp/config/init.lua:11-21,40`; rename `buferFilter` →
  `buffer_filter` (`bufferline.lua:10,55`), `langauge_configs` → `language_configs`
  (`lsp/config/init.lua:10,28,43,57`), `defaultSelect` → `default_select`, `codeAction` → `code_action`
  (`select/init.lua:10-17`; the module table and its methods `defaultKeymap`, `popupName`,
  `longestEntryLength`, `popupUnderCursorOptions` in `select/code_action.lua` to snake_case, callers updated).
- [x] 2.4 **Green.** 2.1 checks list nothing; `nvim --headless -c 'lua io.write(vim.o.winborder)' -c q`
  prints `rounded`; `make check` passes. **Commit** `refactor: options own winborder, snake_case names, dot
  requires`.

## 3. Autocmds in Lua with `gleb_` augroups (3.2, 4.4, 7.1, 7.2, 7.3)

Scenarios: none (Static layer: `rg`). Regression guards: "session: modified file buffer is auto-written",
"session: unnamed buffer is not auto-written" (auto-save format flag), `make smoke` (no messages).

**Files:** `autocommands.lua`, `plugins/init.lua`, `treesitter.lua`

- [x] 3.1 **Failing test.** `rg -n 'augroup |nnoremap|nvim_create_augroup\("[^g]' lua` and
  `rg -n -A1 'nvim_create_autocmd\(' lua/gleb/autocommands.lua lua/gleb/treesitter.lua | rg -v 'group|nvim_create_autocmd|^--$'`
  → hits (`autocommands.lua:1-34,36,49,71,79`, `plugins/init.lua:20`, `treesitter.lua:22`).
- [x] 3.2 **Implement.** Rewrite `autocommands.lua:1-34` with `nvim_create_augroup(…, { clear = true })` /
  `nvim_create_autocmd`: `gleb_general` (q map as `vim.keymap.set("n", "q", "<Cmd>close<CR>",
  { buffer = event.buf, silent = true, desc = "Window: Close" })`, `vim.hl.on_yank`, `formatoptions`, qf
  `buflisted = false`, `~/.zshrc`/`~/.zprofile` → `sh`), `gleb_git_commit`, `gleb_markdown`
  (`wrap`/`spell` via `vim.opt_local`), `gleb_auto_resize` (`tabdo wincmd =`), `gleb_alpha`
  (`AlphaReady` sets `showtabline = 0` and adds a `once = true` `BufUnload` autocmd on that buffer
  restoring 2). Callbacks longer than a few lines are named local functions.
- [x] 3.3 **Implement.** Rename `_lsp` → `gleb_lsp_format`, `_autosave_format` → `gleb_autosave_format`;
  put the `CmdlineEnter`/`CmdlineLeave` autocmds (`autocommands.lua:71,79`) in `gleb_search_hlsearch`;
  give `treesitter.lua:22` augroup `gleb_treesitter`; rewrite `plugins/init.lua:19-24` with augroup
  `gleb_plugins_reload` (`BufWritePost` `plugins.lua`, callback `source` + `Lazy sync`).
- [x] 3.4 **Green.** 3.1 checks list only `99PromptKeymaps` and `DiffPreviewFocusGuard` (spec-pinned,
  design.md Non-Goals); in a headless child `:help help` then `q` closes the help window, and
  `nvim_get_autocmds({ group = "gleb_general" })` is non-empty; `make check` passes. **Commit**
  `refactor(autocmds): Lua autocmds in gleb_ augroups`.

## 4. Plugin config into modules (2.2, 3.5, 6.1)

Scenarios: none (Static layer: `rg`). Regression guards: "statusline: copilot glyph hidden before load",
"statusline: copilot glyph hidden when healthy", "statusline: copilot glyph shown when disabled",
"statusline: copilot glyph shown on warning", "git: Git commands are available after startup", "git:
Gitlink copies current line URL", the `shortcuts` chain/stack rows (smart-splits maps).

**Files:** `copilot.lua` (new), `smart_splits.lua` (new), `plugins/plugins.lua`, `alpha.lua`,
`git/gitlink.lua`, `folding/init.lua`, `debugging/ui.lua`, `testing.lua`, `statusline/language.lua`

- [x] 4.1 **Failing test.** `rg -n 'require\("(copilot|smart-splits)"\)\.setup' lua/gleb/plugins/plugins.lua`,
  `rg -n '":[^"]*<CR>"' lua/gleb/alpha.lua` and
  `rg -L 'pcall\(require' lua/gleb/{git/gitlink,folding/init,debugging/ui,testing}.lua` → hits;
  `rg -n '^local devicons = require' lua/gleb/statusline/language.lua` → hit.
- [x] 4.2 **Implement.** `copilot.lua`: pcall guard, the setup table from `plugins.lua:408-418`, the two
  blink `User` autocmds in augroup `gleb_copilot_blink`. `smart_splits.lua`: pcall guard, the setup table
  from `plugins.lua:295-300`. The specs' `config` only requires the module; copilot keeps `cmd`/`event`,
  smart-splits keeps `lazy = false`.
- [x] 4.3 **Implement.** Alpha buttons use `<Cmd>…<CR>`: `"<Cmd>Telescope find_files<CR>"`,
  `"<Cmd>ene | startinsert<CR>"`, … `"<Cmd>qa<CR>"`.
- [x] 4.4 **Implement.** `pcall(require)` guard with early return at the top of `git/gitlink.lua`
  (gitlinker and `gitlinker.hosts`), `folding/init.lua`, `debugging/ui.lua` (dap and dapui), `testing.lua`
  (neotest and neotest-golang). `statusline/language.lua` loads devicons with `pcall` and `logo()` returns
  `""` without it.
- [x] 4.5 **Green.** 4.1 checks list nothing; in a headless child with gitlinker, ufo, dapui and neotest
  removed from the runtimepath (`child.disable_plugin`), requiring each guarded module raises no error;
  `package.loaded.copilot` is nil after a bare start; `make check` passes. **Commit**
  `refactor(plugins): copilot and smart-splits config in modules, guards, <Cmd> buttons`.

## 5. Lazy-load triggers (2.4)

Scenarios: none (Static layer: headless probe). Regression guards: all scenarios, `make smoke` (startup
budget, no messages, health).

**Files:** `plugins/plugins.lua`, `init.lua`

- [x] 5.1 **Failing test.** `nvim --headless -c 'lua for _, n in ipairs({"neotest","nvim-dap","nvim-dap-ui","nvim-dap-go","nvim-surround"}) do io.write(n, "=", tostring(require("lazy.core.config").plugins[n]._.loaded ~= nil), " ") end' -c q`
  → all `true`.
- [x] 5.2 **Implement.** neotest: `cmd = "Neotest"`. DAP: one nvim-dap spec with `cmd` for the `Dap*`
  commands it uses (`DapContinue`, `DapToggleBreakpoint`, …), dependencies nvim-dap-ui, nvim-dap-go,
  nvim-nio, and `config` requiring `gleb.debugging`; delete `init.lua:20`. nvim-surround:
  `event = "VeryLazy"`, `opts = {}` instead of the inline `config`.
- [x] 5.3 **Green.** The 5.1 probe prints all `false`; `:DapContinue` stub and `:Neotest summary` load
  their plugin in a headless child without error; nvim-surround is loaded after `child.wait_very_lazy()`;
  `make smoke` passes; `make check` passes. **Commit** `perf(plugins): lazy-load neotest, dap and surround`.

## 6. Comments (9.2)

Scenarios: none (Static layer: `rg`). Regression guards: `make check`.

**Files:** `options.lua`, `autocommands.lua`, `select/init.lua`, `indentline.lua`, `bufferline.lua`

- [ ] 6.1 **Failing test.** `rg -n 'TODO' lua/gleb/{autocommands,options}.lua lua/gleb/select/init.lua`
  and `rg -n '^\s*--\s*[a-z_.]+\s*[=(]' lua/gleb/{indentline,bufferline}.lua` → hits.
- [ ] 6.2 **Implement.** Delete `options.lua:50` (the `BufWinEnter` autocmd in `gleb_general` does the job),
  the `autocommands.lua` TODO comments, `select/init.lua:1-8`, the commented-out code in
  `indentline.lua:6-45,52-55` and `bufferline.lua:30,33`.
- [ ] 6.3 **Green.** 6.1 checks list nothing; `make check` passes. **Commit** `chore: drop commented-out code
  and stale TODOs`.

## 7. LuaCATS (5.1)

Scenarios: none (Static layer: `make types`). Regression guards: `make check`.

**Files:** `statusline/copilot.lua`, `statusline/language.lua`, `statusline/lsp_progress.lua`,
`session/key.lua`, `git/ai_commit.lua`, `file_tree/diff_preview.lua`

- [ ] 7.1 **Failing test.** `rg -n -B1 '^function M[.:]' lua/gleb/{statusline/copilot,statusline/language,statusline/lsp_progress,session/key,git/ai_commit,file_tree/diff_preview}.lua | rg -v '@return|^--$'`
  → `copilot.component`, `language.component`, `lsp_progress.progress`, `key.slugify`,
  `key.session_name`, `key.resolve` (`name` param), `ai_commit.show_commit_input`,
  `diff_preview.open_diff`, `close_current_diff`, `focus_neo_tree`, `close_all_diffs`, `reset`.
- [ ] 7.2 **Implement.** `---@param` for every parameter and `---@return` for each of them.
- [ ] 7.3 **Green.** 7.1 check lists nothing; `make types` green; `make check` passes. **Commit**
  `docs(types): annotate exported functions`.

## 8. Gate

- [ ] 8.1 Re-run every **Failing test** check from groups 1-7: only the hits named in 3.4 remain.
- [ ] 8.2 `openspec validate cleanup-convention-targets --strict` passes; `make check` green.
