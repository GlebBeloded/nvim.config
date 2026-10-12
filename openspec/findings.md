# Baseline spec audit findings (2026-10-12)

Found while writing the baseline specs. The specs describe current behaviour, these items included.
Each one becomes an OpenSpec change (`/opsx:propose fix-…`) with a failing test first.

## High
- keymaps: `vim.g.mapleader = "<D->"` is a literal string, and it is set after lazy.nvim loads. Plugin `<leader>` maps (diffview `<leader>c*`) bind to the wrong keys.
- git: neo-tree `c` commits even on `# No staged changes` / `# Error` lines and reports "Committed:" without checking the exit code.
- git: neo-tree `<space>` stage toggle uses a substring match (`a.lua` matches `aa.lua`) and compares a cwd-relative path with git-root-relative paths.
- session: the fallback session match is suffix-only (`/foo/bar` matches `/baz/foo/bar`) and is not most-recent despite the comment.
- session: `nvim file` skips restore but still saves on exit, which overwrites the pane session with one file.
- statusline: an LSP progress task without an `end` event spins forever, and the 100 ms timer never stops.

## Medium
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
- ai: the model string is hard-coded twice.

## Test gaps
- Weak existing tests: diff_preview "should create a new tab" asserts `>=`, and "should track original tab" checks its own assignment.
- The debug-log tests wait 3000 ms against a 2000 ms flush, which is flaky.
- Most keymap, statusline and git scenarios have no tests yet. Screenshot scenarios need mini.test screen references.
