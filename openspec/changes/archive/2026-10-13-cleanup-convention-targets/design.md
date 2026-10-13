# Design

## Context

See proposal.md (Why, What Changes). Every file:line in the proposal was re-checked on 2026-10-12. Facts
that shape the approach:

- Most `gleb` modules are required from `init.lua` after `lazy.setup()` and require their plugin at
  load time, which makes lazy.nvim load that plugin at startup. A trigger on a spec therefore only helps
  when the module that configures it moves into the spec's `config` and nothing at startup requires the
  plugin.
- Spec-pinned names: the ai spec names augroup `99PromptKeymaps` (requirement and scenario); the git spec
  requires `require("gleb.git")` to load gitsigns, differ, diffview and gitlink in order and the
  `DiffviewOpen` and `Gitlink` commands to exist after startup.
- `tests/quick.sh` maps `lua/gleb/lualine.lua` to the statusline capability; after the move,
  `lua/gleb/statusline/*` is mapped by its generic folder rule.
- `make trace` fails on test cases whose name matches no scenario, and this change has no spec delta
  (`skip_specs: true`), so it cannot add new named test cases.
- No screen output changes: alpha shows the button shortcut and label, not the rhs; the bufferline and
  statusline keep their components. No render is needed.

## Goals / Non-Goals

**Goals:**
- Each rule listed in the proposal has no remaining hit at the listed sites, and every existing scenario
  still passes (`make check`), including smoke startup time and health.

**Non-Goals:**
- Items another queued change owns. Re-checking found three more overlaps, now left to their owners:
  - 1.3 `ai/pi_provider.lua` lazy `BaseProvider`: `refactor-ai-99-config`, which already lists it.
  - 1.6 `init.lua:8` comment: `fix-mapleader`, which rewrites the comments on `init.lua:8-9`.
  - 9.2 `debugging/init.lua:1` commented require: `cleanup-keymaps`, whose Decision deletes
    `debugging/keybindings.lua` and that require.
- Renaming augroup `99PromptKeymaps` (4.4): the ai spec pins the name, so it needs a spec delta. It is
  queued as change `rename-ai-prompt-augroup`.
- Renaming augroup `DiffPreviewFocusGuard` (4.4): since `fix-diff-preview-stale-tab` the file-tree
  scenario "Return clears tab state and focus guard" pins the name. Queued as `rename-diff-preview-augroup`.
- Lazy-loading plugins whose config the git spec pins to `require("gleb.git")` (gitsigns, differ,
  diffview, gitlinker), or that startup modules require (telescope and project via `keymaps.lua`,
  smart-splits, treesitter, lsp and its helpers, blink, ufo, lualine, bufferline, alpha, neo-tree,
  resession, auto-save, colors).

## Decisions

### Verification is a grep per rule, not new test cases
Each task starts with a `rg` command that lists the current hits (red) and ends with it listing none
(green), plus `make check`. Alternative: a mini.test static "conventions" file; rejected, because its
cases would be orphans in `make trace` without scenarios, and a spec for the conventions belongs to the
review, not to a capability. Behaviour stays covered by the existing scenarios.

### 1.2 lualine moves to `statusline/lualine.lua`
`statusline/init.lua` would be the natural entry, but `statusline/` modules are libraries required by
lualine and by tests (`gleb.statusline.language`, `.copilot`, `.lsp_progress`, `.palette`), and turning
`init.lua` into the setup would run lualine setup whenever a test requires a part. So the setup goes to
`statusline/lualine.lua` and `statusline/init.lua` requires it (rule 1.1); `init.lua` requires
`gleb.statusline`. Tests requiring `gleb.statusline.<part>` are unaffected because Lua loads the part
without running `init.lua`.

### 1.4 session returns nothing
`require("gleb.session")` is only called from `init.lua:24` and its value is unused, so both
`return {}` become a bare `return` / nothing.

### 1.7 options
`vim.o.winborder` moves to `options.lua` (it is global UI, not LSP-owned). `set background=dark` stays in
the colorscheme module, written as `vim.o.background = "dark"` with a comment that the colorscheme owns
it (it must be set before `:colorscheme`).

### 2.2 copilot and smart-splits configs move to modules
- `lua/gleb/copilot.lua`: `setup()` plus the two blink `User` autocmds in augroup `gleb_copilot_blink`
  (fixes 7.1). The spec keeps `cmd`/`event` and calls `require("gleb.copilot")` from `config`, so
  Copilot still never loads before `InsertEnter` (statusline Key decision).
- `lua/gleb/smart_splits.lua`: the setup table; the spec stays `lazy = false` (keymaps need it at load).
Both start with the rule 6.1 `pcall(require)` guard. Alternative `opts = {…}` in the spec for
smart-splits: rejected, rule 2.2 asks for the config in a module.

### 2.4 lazy-load only plugins with no startup consumer
- neotest: `cmd = "Neotest"`; its config is already `gleb.testing` from the spec.
- nvim-dap, nvim-dap-ui, nvim-dap-go: `require("gleb.debugging")` moves from `init.lua` to the
  nvim-dap spec `config`, with `cmd` for the `Dap*` commands; dap-ui and dap-go become dependencies so
  they load with it. Nothing else requires dap (the `dap-repl` filter in `bufferline.lua` is a filetype
  string).
- nvim-surround: `event = "VeryLazy"`, `opts = {}` instead of the inline `config` (rule 2.3).
- nvim-colorizer: stays at startup; `gleb.colors` requires it while loading.
Each move is checked with `make smoke` (startup time within budget, no messages) and `:Lazy` showing the
plugin not loaded after a bare start.

### 3.2, 7.2, 4.4 autocommands rewritten in Lua
`autocommands.lua` and `plugins/init.lua` replace the Vimscript blocks with `nvim_create_augroup(…,
{ clear = true })` and `nvim_create_autocmd`, one augroup per purpose:
`gleb_general` (qf/help/man/lspinfo `q` map via `vim.keymap.set(…, { buffer = event.buf, silent = true,
desc = "Window: Close" })`, yank highlight, `formatoptions`, qf `nobuflisted`, zsh filetypes),
`gleb_git_commit`, `gleb_markdown`, `gleb_auto_resize`, `gleb_alpha` (the nested `BufUnload <buffer>`
autocmd becomes a `once = true` buffer autocmd in the same group), `gleb_lsp_format`,
`gleb_autosave_format`, `gleb_search_hlsearch` (the two `CmdlineEnter/Leave` autocmds, 7.1),
`gleb_plugins_reload`, `gleb_treesitter` (7.1), `gleb_file_tree_focus_guard`. Callbacks longer than a few
lines are named local functions (7.3).

### 3.5 alpha buttons use `<Cmd>`
`":ene <BAR> startinsert <CR>"` becomes `"<Cmd>ene | startinsert<CR>"`, the others the same way. The
file is renamed `alpha.lua` (4.1); the `require` and the architecture.md startup notes that name
`alpha-nvim` as a module are updated.

### 6.1 guards
`git/gitlink.lua`, `folding/init.lua`, `debugging/ui.lua`, `testing.lua` start with
`local ok, mod = pcall(require, …)` and return when it fails (`testing.lua` guards both neotest and
neotest-golang). `statusline/language.lua` loads devicons with `pcall` and renders the chip without a
logo when it is missing.

### 9.2 comments
`options.lua:50` `formatoptions-=cro` line and its TODO go: ftplugins reset it, which is why the
`BufWinEnter` autocmd exists and does the job. The `autocommands.lua:65,70` TODOs go (no planned move).
`select/init.lua:1-8` TODO list, `indentline.lua` commented-out code and `bufferline.lua:30,33` commented
icons are deleted.

## Risks / Trade-offs

- [Merge conflicts with queued changes touching the same files: `cleanup-hygiene` (`lualine.lua`),
  `fix-diff-preview-stale-tab` (`diff_preview.lua`), `fix-empty-nerd-font-glyphs`
  (`statusline/copilot.lua`, `language.lua`), `fix-session-save-guards` (auto-save spec next to
  smart-splits)] → each task is a separate commit; whichever change lands second rebases, and the later
  change's file:line references are re-checked during its apply.
- [Lazy-loaded DAP or neotest misses a startup side effect (signs, highlight groups)] → `gleb.debugging`
  runs as one unit in the spec `config`; DAP signs only matter once a session runs, which loads dap.
- [Rewriting the Vimscript autocmds changes their behaviour subtly (`autocmd!` inside a group, `<buffer>`
  scope)] → `clear = true` matches `autocmd!`; the `q` map and `showtabline` restore are checked by hand
  in a headless child via `make smoke` and the existing integration tests.
- [lazy `cmd` stubs] → `exists(":Neotest")` and `:DapContinue` still resolve via lazy.nvim's command
  stubs, so commands typed before first load still work.
