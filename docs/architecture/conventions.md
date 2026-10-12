# Conventions

The rules the AI consistency gate checks on every change. They come from how the code is written today.

- **Current practice**: most of the code already does this. New code must follow it.
- **Target**: the code is inconsistent. New and touched code must follow the target. The listed exceptions
  are cleanup candidates, not precedent.

Paths are relative to `lua/gleb/` unless they start with `init.lua`, `tests/` or `openspec/`.

## 1. Module layout

| # | Rule | Status | Examples |
|---|---|---|---|
| 1.1 | A feature lives in `lua/gleb/<feature>/`, and `init.lua` only requires its parts in order. | Current practice | `git/init.lua:1-4`, `debugging/init.lua:1-4`, `lsp/init.lua:1-2` |
| 1.2 | A feature with more than one file is a folder, not a top-level file plus a folder. | Target | `lualine.lua` + `statusline/`; `telescope.lua`, `bufferline.lua` are fine as single files |
| 1.3 | Pure logic goes in its own file with no plugin requires, so it can be tested without plugins. | Target | `session/key.lua:1-2` is pure. `ai/pi_provider.lua:1` requires 99 at the top, so its tests need the plugin |
| 1.4 | A module with an API is `local M = {}` … `return M`. A module that only configures returns nothing. | Current practice | `statusline/language.lua:5,100`, `git/ai_commit.lua:2,204`; `git/gitsigns.lua` returns nothing. Exception: `session/init.lua:13,52` returns `{}` |
| 1.5 | Module state that tests must reset lives in `M.state` with an `M.reset()`. | Current practice | `file_tree/diff_preview.lua:8-13,183-192` |
| 1.6 | `init.lua` order is load order. If a line must come before or after another, say why in a trailing comment, and keep the comment true. | Target | `init.lua:15-17,24` are true; `init.lua:8-9` are false (see [README](README.md#startup-sequence)) |
| 1.7 | Editor options are set in `options.lua`. A feature sets only the options it owns, such as fold options. | Target | `lsp/init.lua:4` overrides `updatetime` from `options.lua:22`; `folding/init.lua:3-7` is fine |
| 1.8 | Tests live in `tests/<feature>/<name>_spec.lua`. | Target | `tests/ai/`, `tests/file_tree/`; `nvim_debug_log/tests/`, `session/tests/` are inside `lua/` |

## 2. Plugin specs and wiring

| # | Rule | Status | Examples |
|---|---|---|---|
| 2.1 | Every plugin is declared once in `plugins/plugins.lua`, with a short comment saying what it is for. | Current practice | `plugins/plugins.lua:150-156,244-246` |
| 2.2 | Plugin configuration lives in a `gleb` module, not in the spec. The spec either says where (`-- configured in lua/gleb/git/differ.lua`) or calls it from `config`. | Target | Good: `plugins.lua:29-31,187-189,246,255-257`. Inline: 99 `plugins.lua:323-358`, copilot `:402-428`, auto-save `:272-281`, smart-splits `:289-296` |
| 2.3 | Use `opts = {}` when a plugin only needs `setup(opts)`. | Current practice | `plugins.lua:12-17,218-222,364,392` |
| 2.4 | A plugin that is not needed at startup is lazy-loaded with `event`, `ft`, `cmd` or `keys`, and its config is required from the spec, not from `init.lua`. | Target | `plugins.lua:319` (VeryLazy), `:401` (InsertEnter), `:11` (ft). Most plugins are start plugins |
| 2.5 | Code that runs on every redraw must not require a lazy plugin. Check `package.loaded` or `pcall` inside the function. | Current practice | `statusline/copilot.lua:8-12`, `lualine.lua:50-53` |
| 2.6 | Spec fields are spelled right; lazy.nvim ignores unknown keys. | Target | `plugins.lua:24` `priorty` |
| 2.7 | No plugins that duplicate a built-in or another plugin, unless the spec says why. | Target | `impatient.nvim` (`plugins.lua:8`) next to `vim.loader.enable()` (`options.lua:59`); mini.diff and gitsigns both draw signs (findings.md) |

## 3. Keymaps

| # | Rule | Status | Examples |
|---|---|---|---|
| 3.1 | Global editor keymaps go in `keymaps.lua`. A feature's keymaps go in its module. Keymaps for a plugin's own windows go in that plugin's setup table. Buffer-local keymaps are set from a `FileType` autocmd with `buffer = event.buf`. | Current practice | `keymaps.lua`; `comments/init.lua:3-4`, `folding/init.lua:10-14`; `file_tree/init.lua:155-175,212-222`, `git/diffview.lua:29-55`; `ai/prompt_keymaps.lua:3-17` |
| 3.2 | Use `vim.keymap.set`. No `vim.api.nvim_set_keymap`, no Vimscript `map` commands. | Current practice | `keymaps.lua:2`. Exception: `autocommands.lua:4` (`nnoremap` in an autocmd) |
| 3.3 | Every new keymap has a `desc` of the form `"<Area>: <Action>"`. | Target | `plugins.lua:354-357` (`"99: Menu"`), `ai/prompt_keymaps.lua:6`. None in `keymaps.lua` |
| 3.4 | Options are `{ silent = true, desc = … }`. `noremap` is the default of `vim.keymap.set`; set `remap = true` only when the right side is a mapping. | Target | `comments/init.lua:1` (`remap = true` for `gcc`, correct). `keymaps.lua:1` repeats `noremap = true` |
| 3.5 | The right side is a function reference, a named local function, or `<Cmd>…<CR>`. No `:…<CR>` strings in new maps, and no long anonymous functions. | Target | `keymaps.lua:101-106`, `ai/prompt_keymaps.lua:4`. Strings: `keymaps.lua:19-22,32,87` |
| 3.6 | One mode per behaviour: use `x` for visual-mode maps, not both `v` and `x` for the same keys. | Target | `keymaps.lua:42-43` vs `:49-50`, `:97-98` (findings.md) |
| 3.7 | Cmd shortcuts arrive as `<A-…>` from Alacritty. Window moves use smart-splits so they cross into zellij. | Current practice | `keymaps.lua:6-12`, `docs/KEYBINDINGS.md` |
| 3.8 | No `<leader>` maps until the leader is fixed (findings.md, High). Core keymap changes need user approval (`openspec/config.yaml`). | Current practice | `git/diffview.lua:34-37` are the only leader maps |
| 3.9 | Don't use deprecated APIs. | Target | `keymaps.lua:109-115` (`vim.diagnostic.goto_*`) |

## 4. Naming

| # | Rule | Status | Examples |
|---|---|---|---|
| 4.1 | Files and folders are `snake_case.lua`. OpenSpec capabilities are the kebab-case module name. | Target | `file_tree/diff_preview.lua`, `nvim_debug_log/` → `nvim-debug-log`. Exception: `alpha-nvim.lua` |
| 4.2 | `require` paths use dots. | Target | `lsp/config/init.lua:11-21` use `"gleb/lsp/config/go"` |
| 4.3 | Locals and functions are `snake_case`; tunable constants are `UPPER_SNAKE` at the top of the file. | Current practice | `statusline/lsp_progress.lua:11-13`, `statusline/language.lua:14-25`, `file_tree/diff_preview.lua:17-18`. Exceptions: `bufferline.lua:10` `buferFilter`, `lsp/config/init.lua:10` `langauge_configs` |
| 4.4 | Augroups are `gleb_<feature>` or `gleb_<feature>_<purpose>`. | Target | `session/init.lua:37`, `statusline/lsp_progress.lua:126`. Others: `_general_settings` (`autocommands.lua:2`), `99PromptKeymaps` (`ai/prompt_keymaps.lua:11`), `DiffPreviewFocusGuard` (`file_tree/diff_preview.lua:21`) |
| 4.5 | Highlight groups are PascalCase with an area prefix, and names built from data are sanitized. | Target | `StatuslineLang*` (`statusline/language.lua:28-33`); `StatuslineLang_<filetype>` (`:66`) is not sanitized (findings.md) |
| 4.6 | User commands are PascalCase nouns or verbs. | Current practice | `:Gitlink` (`git/gitlink.lua:9`), `:MasonSync`, `:Run`, `:Format` |

## 5. Types (LuaCATS)

| # | Rule | Status | Examples |
|---|---|---|---|
| 5.1 | Every function exported on `M` has `---@param` and `---@return`. | Target | Done: `colors/gruvbox-material/util/convert.lua:3-6,25-28`. Missing: `statusline/*.lua`, `session/key.lua`, `git/ai_commit.lua`, `file_tree/diff_preview.lua` |
| 5.2 | Module state and option tables get a `---@class`, and constant lists get `---@type`. | Target | `treesitter.lua:4`, `plugins.lua:50` (`LazyPluginSpec`), `file_tree/diff_preview.lua:60` (`SessionConfig`) |
| 5.3 | Plugin types come from lazydev; don't redefine a plugin's types. | Current practice | `plugins.lua:9-18` |

## 6. Errors and optional plugins

| # | Rule | Status | Examples |
|---|---|---|---|
| 6.1 | A module that configures a plugin starts with `local ok, mod = pcall(require, "<plugin>")` and returns early when it fails. Specs test this ("Missing … is tolerated"). | Target | Done: `git/gitsigns.lua:1-4`, `git/differ.lua:1-4`, `file_tree/init.lua:1-4`, `lualine.lua:1-4`. Missing: `git/gitlink.lua:1` (findings.md), `folding/init.lua:1`, `debugging/ui.lua:1`, `testing.lua:1`, `statusline/language.lua:7`, `keymaps.lua:9,105` |
| 6.2 | Use `pcall` around commands that may fail and whose failure doesn't matter, such as `colorscheme`, `tabclose`, `treesitter.start`. | Current practice | `colors/gruvbox-material/init.lua:9`, `file_tree/diff_preview.lua:81`, `treesitter.lua:24` |
| 6.3 | Async callbacks call Neovim through `vim.schedule` and check that the window or buffer is still valid, and that the request is still current. | Current practice | `git/ai_commit.lua:57,143,190`, `file_tree/diff_preview.lua:36,52-56,76` |
| 6.4 | Run external commands with `vim.system` and an argument list, check the exit code, and show the failure. | Target | `git/ai_commit.lua:41-71` checks the code. `file_tree/init.lua:71-73,82` use `vim.fn.system` strings and ignore the result (findings.md) |
| 6.5 | Timers and jobs stop themselves when idle and on exit. | Target | `statusline/lsp_progress.lua:68-85` (stops only when idle, findings.md), `nvim_debug_log/init.lua:17-22` |

## 7. Autocmds

| # | Rule | Status | Examples |
|---|---|---|---|
| 7.1 | Use `vim.api.nvim_create_autocmd` with a `group` from `nvim_create_augroup(name, { clear = true })`, so re-sourcing doesn't duplicate it. | Target | Done: `session/init.lua:37-50`, `statusline/lsp_progress.lua:125-128`, `ai/prompt_keymaps.lua:11-16`. No group: `statusline/language.lua:37`, `treesitter.lua:22`, `autocommands.lua:71,79`, `nvim_debug_log/init.lua:17`, `plugins.lua:415,422` |
| 7.2 | No Vimscript `augroup` blocks in new code. | Target | `autocommands.lua:1-34`, `plugins/init.lua:19-24` |
| 7.3 | The callback is a named local function when it is longer than a few lines. | Current practice | `session/init.lua:44`, `statusline/lsp_progress.lua:127`, `ai/prompt_keymaps.lua:15` |
| 7.4 | Use `nested = true` only when the callback opens buffers that need their own events, and say so in a comment. | Current practice | `session/init.lua:39-43` |

## 8. Notifications and UI

| # | Rule | Status | Examples |
|---|---|---|---|
| 8.1 | Use `vim.notify(msg, vim.log.levels.X)`, never `print`. INFO for progress and success, ERROR for failures with the error text. | Current practice | `file_tree/init.lua:85-97`, `file_tree/diff_preview.lua:37,47` |
| 8.2 | Messages are short and sentence-case, without a trailing period: `"Pushing..."`, `"Push failed"`, `"Committed: <subject>"`. | Current practice | `file_tree/init.lua:85-97` |
| 8.3 | Report success only after checking the result. | Target | `file_tree/init.lua:82-85` says "Committed:" without checking (findings.md) |
| 8.4 | Background work is silent. | Current practice | `session/init.lua:19` (`notify = false`), `session/init.lua:29` (`silence_errors`) |
| 8.5 | Use `vim.api.nvim_echo` with a highlight group for one-key prompts. | Current practice | `plugins.lua:337` |
| 8.6 | Floating windows and popups use `border = "rounded"`. | Current practice | `git/ai_commit.lua:92`, `file_tree/init.lua:110`, `lsp/config/handlers.lua:24` |
| 8.7 | Colors come from the gruvbox-material palette helpers, never hard-coded hex. | Current practice | `statusline/palette.lua:1-2`, `bufferline.lua:8` |
| 8.8 | A change with visible UI includes a Current render and Proposed renders ([design-renders.md](../design-renders.md), `openspec/config.yaml` `rules.design`). | Current practice | this page's [worked example](../design-renders.md#worked-example-language-chip-variants) |

## 9. Comments and style

| # | Rule | Status | Examples |
|---|---|---|---|
| 9.1 | A file that holds a design starts with a comment explaining it: what, why, how to tune. | Current practice | `statusline/lsp_progress.lua:1-8`, `session/init.lua:1-9`, `statusline/language.lua:1-4` |
| 9.2 | Comments explain why, not what. No commented-out code or stale TODOs. | Target | `indentline.lua:6-40`, `debugging/init.lua:1`, `options.lua:50`, `autocommands.lua:65,70`, `select/init.lua:1-8` |
| 9.3 | Comments match the code. | Target | `lualine.lua:94` says bufferline, sets `laststatus`; `file_tree/init.lua:79` mentions an Alt+C that doesn't exist |
| 9.4 | Format with stylua (`make fmt`) and lint with selene (`make lint`, `std = "vim"`). | Current practice | `Makefile`, `selene.toml` |
| 9.5 | Icon strings are not empty. Some Nerd Font glyphs were lost from the source, so check icon fields with `grep -n '= ""'` after editing. | Target | Empty today: `statusline/language.lua:24-25`, `statusline/copilot.lua:6`, `file_tree/init.lua:120-126`, `lsp/config/handlers.lua:12-15`, `debugging/gutter.lua:5-7` |
