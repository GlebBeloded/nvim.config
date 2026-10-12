## Why
the conventions in `docs/architecture.md` lists rules with Status "Target" whose exceptions are cleanup candidates, not precedent. They are still in the code (verified 2026-10-12, current file:line below), so new code keeps copying them and the consistency gate keeps flagging them. Pure refactor: no behaviour changes, so no spec delta.

Kind: bug

## What Changes
Grouped by rule number (paths relative to `lua/gleb/`).
- 1.2 Feature split across a top-level file and a folder: `lualine.lua` + `statusline/`. Move the lualine setup into `statusline/` (e.g. `statusline/init.lua`) and update `init.lua:27`.
- 1.3 Pure logic with plugin requires: `ai/pi_provider.lua:1` requires `99` at module top; resolve `BaseProvider` lazily or split the pure part, so `tests/unit/ai/test_pi_provider.lua` runs without the plugin.
- 1.4 Configure-only module returns a value: `session/init.lua:13` and `:52` `return {}`; return nothing (check that no caller uses the value).
- 1.6 False ordering comment: `init.lua:8` `-- must be loaded before lazy.nvim` (lazy is already loaded at `init.lua:6`). `init.lua:9` (mapleader) belongs to change `fix-mapleader`.
- 1.7 Global editor options set outside `options.lua`: `lsp/config/handlers.lua:34` `vim.o.winborder`; `colors/gruvbox-material/init.lua:7` `set background=dark` may stay if documented as colorscheme-owned. (`lsp/init.lua:4` updatetime is change `cleanup-hygiene`.)
- 2.2 Inline plugin config in the spec: copilot `plugins/plugins.lua:397-429` (setup plus two `User` autocmds) and smart-splits `plugins/plugins.lua:286-297`; move to `gleb` modules called from `config`. (99 is `refactor-ai-99-config`, auto-save is `fix-session-save-guards`.)
- 2.4 Lazy loading: only `plugins/plugins.lua:11,159,319,365,391,400-401` use `ft`/`cmd`/`event`; audit start plugins that are not needed at startup and give them a trigger, without breaking startup-dependent specs.
- 3.2 Vimscript map: `autocommands.lua:4` `nnoremap <silent> <buffer> q :close<CR>` in a `FileType` autocmd; replace with `vim.keymap.set` from a Lua `FileType` autocmd.
- 3.5 `:…<CR>` strings: `alpha-nvim.lua:16-22` dashboard buttons; use `<Cmd>…<CR>`. (`keymaps.lua` strings are change `cleanup-keymaps`.)
- 4.1 File name not snake_case: `alpha-nvim.lua` -> `alpha.lua` (or `dashboard.lua`); update `init.lua:24-25`.
- 4.2 Slash require paths: `lsp/config/init.lua:11-21` and `:40` `require("gleb/lsp/config/...")`; use dots.
- 4.3 Naming: `bufferline.lua:10,55` `buferFilter`; `lsp/config/init.lua:10,28,43,57` `langauge_configs`; also `select/init.lua:10-11` `defaultSelect`, `codeAction`.
- 4.4 Augroup names not `gleb_<feature>[_<purpose>]`: `autocommands.lua:2,12,18,24,29` (`_general_settings`, `_git`, `_markdown`, `_auto_resize`, `_alpha`), `autocommands.lua:36` `_lsp`, `:49` `_autosave_format`, `plugins/init.lua:20` `lazy_user_config`, `ai/prompt_keymaps.lua:11` `99PromptKeymaps`, `file_tree/diff_preview.lua:21` `DiffPreviewFocusGuard`. Tests that reference these names must be updated.
- 5.1 Exported functions without `---@param`/`---@return`: `statusline/copilot.lua:28`, `statusline/language.lua:87`, `statusline/lsp_progress.lua:108`, `session/key.lua:7,12,23`, `git/ai_commit.lua:83`, `file_tree/diff_preview.lua:117,148,161,174,183`.
- 6.1 Plugin modules without a `pcall(require)` guard: `git/gitlink.lua:1,5` (startup errors if gitlinker is missing; spec scenario "Missing optional git plugins are tolerated"), `folding/init.lua:1`, `debugging/ui.lua:1`, `testing.lua:1,3`, `statusline/language.lua:7`. (`keymaps.lua:9,105` are change `cleanup-keymaps`.)
- 7.1 `nvim_create_autocmd` without a group: `treesitter.lua:22`, `autocommands.lua:71,79`, copilot `plugins/plugins.lua:415,422` (moves with 2.2). (`statusline/language.lua:37` is `fix-language-chip-highlights`, `nvim_debug_log/init.lua:17` is `fix-debug-log-redir`.)
- 7.2 Vimscript augroup blocks: `autocommands.lua:1-34`, `plugins/init.lua:19-24`; rewrite with `nvim_create_augroup`/`nvim_create_autocmd` (names per 4.4).
- 9.2 Commented-out code and stale TODOs: `indentline.lua:6-45,52-55`, `debugging/init.lua:1`, `options.lua:50`, `autocommands.lua:65,70`, `select/init.lua:1-8`, `bufferline.lua:30,33` (commented alternative icons).
- 9.5 Empty icon strings: handled by change `fix-empty-nerd-font-glyphs`. Note: `debugging/gutter.lua:5-8` DAP signs are not empty (3-byte Nerd Font glyphs, verified with xxd); so they need no change.

## Capabilities
### Modified Capabilities
None

## Impact
- Code: `init.lua`, `lua/gleb/{lualine.lua,statusline/,ai/pi_provider.lua,ai/prompt_keymaps.lua,session/init.lua,lsp/config/,plugins/,autocommands.lua,alpha-nvim.lua,bufferline.lua,select/init.lua,git/gitlink.lua,folding/init.lua,debugging/,testing.lua,treesitter.lua,indentline.lua,options.lua,file_tree/diff_preview.lua,session/key.lua,git/ai_commit.lua}`, tests that reference renamed augroups or modules, the conventions in `docs/architecture.md`.
- Plugins: none added, removed or upgraded (2.4 changes only lazy-load triggers).
- Core keymaps: unchanged.
- Out of scope: items owned by other changes: `keymaps.lua` (cleanup-keymaps, fix-keymaps-visual-modes, fix-diagnostic-navigation), mapleader and `init.lua:9` (fix-mapleader), 99 inline config (refactor-ai-99-config), auto-save inline config (fix-session-save-guards), `file_tree/init.lua` `vim.fn.system` / 6.4 / 8.3 (fix-neotree-commit-check), `lsp_progress` timer / 6.5 (fix-lsp-progress-stuck-task), `language.lua` augroup and highlight name / 4.5 (fix-language-chip-highlights), debug-log augroup and timer (fix-debug-log-redir), impatient / mini.diff / 2.7 (remove-redundant-plugins), `priorty` / `updatetime` / stale comments 9.3 (cleanup-hygiene), empty glyphs 9.5 (fix-empty-nerd-font-glyphs), LuaLS `undefined-doc-name` 5.2 (fix-type-check-baseline). Rule 1.8 needs no work: tests already live under `tests/<layer>/<capability>/` and no `lua/gleb/*/tests/` dir exists; only the rule text in conventions.md is stale.
