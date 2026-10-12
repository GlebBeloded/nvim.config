# Baseline spec audit findings (2026-10-12)

Found while writing the baseline specs. The specs describe current behaviour, these items included.
Each one becomes an OpenSpec change (`/opsx:propose fix-…`) with a failing test first.

## High
- keymaps: `vim.g.mapleader = "<D->"` is a literal string, and it is set after lazy.nvim loads. Plugin `<leader>` maps (diffview `<leader>c*`) bind to the wrong keys.
- git: neo-tree `c` commits even on `# No staged changes` / `# Error` lines and reports "Committed:" without checking the exit code.
- git: neo-tree `<space>` stage toggle uses a substring match (`a.lua` matches `aa.lua`) and compares a cwd-relative path with git-root-relative paths.
- session: the fallback session match is suffix-only (`/foo/bar` matches `/baz/foo/bar`). Order is fine: resession lists newest first.
- session: `nvim file` skips restore but still saves on exit, which overwrites the pane session with one file.
- statusline: an LSP progress task without an `end` event spins forever, and the 100 ms timer never stops.

- ui: Nerd Font glyph strings are empty (bytes verified). Affected: statusline language caps (`statusline/language.lua:24-25`), the Copilot glyph (`statusline/copilot.lua:6`, empty since 2aa1ce4), neo-tree icons (`file_tree/init.lua:120-147`), LSP diagnostic signs (`lsp/config/handlers.lua:12-15`), DAP signs (`debugging/gutter.lua:5-7`). An earlier edit likely stripped private-use characters. The specs currently assert `""`.

## Medium
- bufferline: the offset targets filetype `NvimTree`, but the tree is `neo-tree`.
- plugins: `priorty` typo in `plugins.lua:24` makes lazy.nvim ignore the priority.
- lsp: `lsp/init.lua:4` sets `updatetime=1000`, which overrides `options.lua` (300).
- init: the mapleader fix belongs at the top of `init.lua`, because keymaps.lua needs smart-splits/telescope at load time.
- git: an AI commit that returns empty output leaves the title stuck on "Generating...".
- git: `gitlink.lua` requires gitlinker without `pcall`, so startup errors if the plugin is missing.
- file-tree: diff preview never clears `state.original_tab`, so it returns to a stale tab.
- keymaps: visual `<A-j>/<A-k>` and `<C-CR>` are mapped in both `v` and `x`, and `x` wins. Visual `J`/`K` override built-ins.
- keymaps: `vim.diagnostic.goto_next/prev` are deprecated in 0.11, and the `border` option has no effect.
- nvim-debug-log: the 2 s flush runs `:redir END` and cuts off any other active `:redir`.
- statusline: `string.format("%d", pct)` may error on fractional percentages.
- statusline: the language chip highlight name is not sanitized for filetypes with `-`.

## Low / hygiene
- `/tmp/nvim-lsp-progress.log` and `/tmp/nvim` debug logs are never cleaned up.
- The language.lua `ColorScheme` autocmd has no augroup.
- statusline: `inactive_sections` are dead with `laststatus=3`, and the diff `cond` uses the current window width.
- git: mini.diff and gitsigns both show hunk signs.
- git: git_status `gr`/`c` shadow the global LSP references and copy maps.
- docs/KEYBINDINGS.md is stale (`<A-g>` is now `:Differ`, neo-tree git status moved to `<A-G>`).
- ai: the model string is hard-coded twice. The 99 menu/keymaps are inline in `plugins.lua`, not in `lua/gleb/ai/`.
- impatient.nvim is installed alongside `vim.loader.enable()`.
- Stale comments: `file_tree/init.lua:79` (Alt+C), `git/vscode_diff.lua:7`, `lualine.lua:94`, `init.lua:8-9`.
- No keymap in keymaps.lua has a `desc`.

## Found by the test pyramid (2026-10-12)
- High file-tree: `diff_preview.open_diff(p)` crashes in the scheduled callback inside codediff `view.create` (`codediff/ui/view/helpers.lua:34: attempt to index local 'ref' (a nil value)`) with the pinned vscode-diff.nvim. No diff tab is created and neo-tree is never opened in it. Tests "Diff tab is created" and "Neo-tree is opened and focused in diff tab" are marked `H.xfail`.
- Medium session: auto-save writes unnamed buffers. Typing in an `:enew` buffer sets `v:errmsg` to `E32: No file name` after the debounce, because the `condition` checks only `buftype` and `filetype`, not the buffer name.
- Low: every Neovim start writes `/tmp/nvim/<time>_<pid>.txt` (nvim-debug-log), and test children are no exception. The harness deletes its own files by pid.

## Static baseline
`make lint` (stylua + selene) is clean. `lsp_progress.lua` was reformatted by stylua with no behaviour change. The plenary busted globals were removed from `vim.toml`.
`make types` (lua-language-server 3.19.1, `--checklevel=Warning`) is green because these codes are downgraded to `Information` in `.luarc.jsonc`. Put each one back to Warning once its hits are fixed:
- `param-type-mismatch` (7): colors/gruvbox-material/init.lua:9, colors/gruvbox-material/util/init.lua:17 (x2), file_tree/diff_preview.lua:81 and :155, plugins/plugins.lua:338, run/init.lua:3.
- `deprecated` (4): keymaps.lua:109, :111 and :114 (`vim.diagnostic.goto_*`, see Medium above), lsp/config/python/typecheck.lua:7.
- `undefined-doc-name` (2): `SessionConfig` (diff_preview.lua:60) and `LazyPluginSpec` (plugins.lua:50). These are plugin types, and plugins are not in the LuaLS library.
- `duplicate-set-field` (1): select/init.lua:13 (`vim.ui.select` override).
- `need-check-nil` (1): statusline/lsp_progress.lua:75 (`timer`).

## Smoke baseline
- Healthchecks are skipped by `make smoke` (list in `tests/smoke/run.lua`):
  - Need external tools: `null-ls` (markuplint, stylelint, shfmt, shellharden, terraform), `rustaceanvim` (rust-analyzer), `mason`, `vim.provider`.
  - Report plugin or config issues: `neo-tree` (`config.buffers.renderers: expected ?, got nil`) and `neotest-golang` (`testify/namespace` and `testify/test_method` queries cannot be loaded).
- Ignored ERROR: lazy `hererocks/bin/luarocks not installed`. lazy itself says "no plugins require luarocks". Proposal: set `rocks = { enabled = false }` in lazy setup.
- Startup: the headless median is about 220-250 ms with warm caches, and the budget is 400 ms (`STARTUP_BUDGET_MS`). The first start with an empty data dir takes about 425 ms.

## Test gaps
- Resolved: the weak diff_preview tests were replaced by mini.test cases that assert the spec. The debug-log cases now find the child's own log by pid and no longer wipe `/tmp/nvim`. They still wait the 3000 ms the spec allows against the 2000 ms flush.
- Screen tests compare attribute *identity*, not colors. The normal and insert accent screenshots therefore share an attr layout, and asserting a color needs `nvim_get_hl` checks.
- Missing scenarios are listed by `make trace` (git, neo-tree mappings, 99 prompts, Copilot states, session restore).
