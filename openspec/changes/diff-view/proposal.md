## Why

Kind: feature
Depends: diff-engine-moves

The user wants IntelliJ's two-side diff, built on the ported engine and with a UI we own 100%. Today `<A-g>` opens differ.nvim. Its layout is a 35-column panel plus a wrapped side-by-side split, with `---` filler and 3 lines of context (Current below). It has no centre gutter, no aligned padding, no unchanged-line folds and no IntelliJ chrome. The engine changes (`diff-engine-lines`, `-words`, `-moves`) give IntelliJ's line and word fragments. This change draws them in the approved look, `diff2_aligned`.

## What Changes

- **`diff.open_file`** is a new, unbound action, reachable from Find Action. It compares the current file at `HEAD` (left) with the current buffer's lines (right).
  - The view opens in a new tab page, with the cursor in the right window on the first change.
  - If the file has no changes, it notifies `No changes` and opens nothing.
  - Outside a git work tree, it notifies `Not in a git repository` and opens nothing.
  - If the file is already shown in a view, that view's tab page is focused.
- **Two windows, aligned.**
  - Left window: a read-only scratch buffer (filetype `gleb-diff`) holding the `HEAD` text, with treesitter highlighting for the file's language.
  - Right window: the file's own buffer, editable, so LSP, autosave and undo keep working. Edits re-diff after a 150 ms debounce.
  - Rows stay level: `╱` padding rows (window-scoped virtual lines) fill the side that has no lines for a change.
- **IntelliJ chrome.** The right window's `statuscolumn` is the centre gutter, in this order:
  1. `»` apply arrow;
  2. the left line number;
  3. a 5-cell change strip;
  4. the right line number;
  5. the include checkbox `☐`.

  The arrow and checkbox get their behaviour in `diff-view-actions`. The winbars read `<short hash> · HEAD` and `Your version`.
- **Folds.** Unchanged runs keep 4 lines of context, IntelliJ's default, and fold the rest into one wavy row, `~~ <n> unchanged lines ~~~`, in both windows. `zo` opens the fold under the cursor in both windows. `zR` opens or closes all of them.
- **Highlights.**
  - Changed lines are tinted by kind (`DiffViewAdd`, `DiffViewChange`, `DiffViewDelete`).
  - Inner word ranges (by-word, IntelliJ's default) are tinted `DiffViewWord`.
  - When the engine falls back (`too_big` or `timed_out`), the right winbar reads `Your version · approximate diff`.
- **Sync scroll.** Scrolling either window scrolls the other to the same aligned row. Moving the cursor moves the other window's cursor to the transferred line (IntelliJ `transferLine`).
- **Navigation and close.**
  - `]c` / `[c` go to the next or previous change, without wrapping.
  - `]f` asks the embedding list (`git-changes-tree`) for the next file. Without a list, it does nothing.
  - `q` closes the view. It removes the view's mappings, extmarks and window options from the file buffer and restores any buffer mapping they shadowed.
- **API** for `git-changes-tree`: `require("gleb.diff.view")`:
  - `open(spec)`: new tab page;
  - `show(win, spec)`: the area of an existing window, focus unchanged;
  - `close(view)`;
  - `current()`.

  `spec` is `{ path, left, right, labels, on_next_file }`.
- **Keys.** They live only in `settings/keymap.json`, as buffer-local mappings set in both windows from `diff.*` actions owned by the `gleb-diff` adapter (rule 3.1):
  - `diff.next_change` `]c`, `diff.prev_change` `[c`, `diff.next_file` `]f`;
  - `diff.expand_fold` `zo`, `diff.toggle_folds` `zR`, `diff.close` `q`.

## Capabilities

### New Capabilities
- none (`diff` is created by `diff-engine-lines`)

### Modified Capabilities
- `diff`: Added "Diff view opens the current file", "Diff view layout", "Diff view folds", "Diff view word highlights", "Diff view synchronized scrolling", "Diff view change navigation", "Diff view editing", "Diff view closing", "Diff view embedding", "Diff view keys" and "Diff view colours".

## Impact

- Code:
  - New: `lua/gleb/diff/init.lua`, `lua/gleb/diff/actions.lua`, `lua/gleb/diff/view/{init,layout,render,windows,source,highlights}.lua` (`layout.lua` is pure) and `lua/gleb/actions/adapters/gleb_diff.lua`.
  - Changed: `init.lua` (register `gleb.diff.actions`, require `gleb.diff`) and `settings/keymap.json` (the six view keys; `diff.open_file` has no entry).
- Tests:
  - unit: layout rows, folds, line transfer and gutter cells (`tests/unit/diff/test_layout.lua`);
  - integration: open, close, sync, navigation, editing and embedding on the new `diffgo` fixture (`tests/fixtures/build.sh`);
  - screen: Proposed D.
- Plugins: none added or removed. Neovim built-ins only: `statuscolumn`, window-scoped extmark namespaces (`nvim__ns_set`), virtual lines and manual folds. differ, diffview and vscode-diff stay until `tree-diff-cutover`.
- Core keymaps: none. `diff.open_file` is unbound, and the view keys are buffer-local to the two diff windows.
- Unchanged scenarios:
  - `git: ]c steps to the next hunk in differ` still holds: differ keeps its plugin-scoped `]c`; the new `]c` is buffer-local to diff-view windows only.
  - `git: ]f steps to the next changed file in differ` still holds: same reason, for `]f`.
  - `git: Differ mappings come from git actions` still holds: differ's adapter and actions are untouched.
  - `git: Codediff mappings come from git actions` still holds: codediff's adapter and actions are untouched.
  - `autocommands: q closes special buffers through an action` still holds: the new `q` is buffer-local to diff-view windows, which are none of `qf`, `help`, `man` or `lspinfo`.
  - `file-tree: q closes preview and tree` still holds: the neo-tree `q` and its diff preview are untouched.
  - `git: q closes diffview from file panel` still holds: diffview's plugin-scoped `q` is untouched.
  - `git: q discards popup` still holds: the commit popup's `q` is untouched.
  - `references: gr classifies Lua function calls and redefinitions` still holds: diff-view adds only `diff.*` actions and does not alter reference classification.
  - `references: Lua usage types match the approved render` still holds: the new view is isolated from the references view and its render.
- Out of scope:
  - Behaviour of the `»` arrow and the checkbox, moved blocks, and whitespace and highlight-mode toggles (`diff-view-actions`).
  - The file list and `]f` targets (`git-changes-tree`).
  - Rebinding `<A-g>` (`tree-diff-cutover`).
  - Files outside git, arbitrary revisions, merges and three-way diffs (diffview stays for merges).
  - Binary files and soft wrap.

## Decision (user, 2026-10-17)

- Engine: "port IDEA one, if it's not ported to lua yet". On a diffbandit-based UI: "is diffbanding perfect? I want to own ui 100%".
- Panes: picked "Aligned, IntelliJ chrome" (numbers in the middle, » apply, checkbox per change, ╱ padding, wavy folds) after a refined connector render. On the connector: "connector strip looks cool but it doesn't actually work like it does in idea".
- General: "I'm used to Idea", "I like IDEA IDE diff more".

## Decision (auditor, 2026-10-17, pre-implementation audit)

- Re-render Proposed D at the real tabstop (global 2; the left buffer copies the right's tabstop), add a "don't check" mask symbol for syntax-coloured code cells, fix the separator fg and the gutter-table cell-16 entry; task 5.1 uses the approved mask only, never one taken from the implementer's capture.
- Isolate the view from shipped behaviour: detach or disable nvim-ufo for both view windows; actions fall through outside view windows (no leaked `q`/`]c`/`zo`/`zR` in other windows of the file); restore window options on every close, `open` included; run close cleanup via `vim.schedule` (a sync close in WinClosed gives E855); one namespace, augroup and timer per view.
- Source: compute the repo-relative path with `git rev-parse --show-prefix` plus the file name (`ls-files` is empty for untracked files, and `git show HEAD:` then returns the tree with exit 0).
- Add scenarios: close via `:tabclose`/`:close`/`:only` with checks that autocmds, attach, timer and options are gone; keys in non-view windows; folds and fold rows after an edit plus auto-save; `show` replacing a view and two views at once; VimResized and a narrow area; empty and zero-change diffs; multibyte words; sync with closed folds, a pad at the top and `leftcol`; a statuscolumn/re-diff perf budget on a large fixture. A task updates `find-action/test_run.lua` `more_results` and `ADAPTER_PLUGINS`.
- Split tasks 2 and 3 into 2a (source, open, notify), 2b (render, pads, gutter, words, colours) and 3a (folds, ufo isolation), 3b (sync), 3c (navigation, keys), 3d (re-diff), so each fits the 2-attempt limit.

## Agent decisions

- **The right pane is the real buffer, not a copy.** IntelliJ edits the document in place. This keeps LSP, autosave, undo and gitsigns, and `diff-view-actions` stages what the user sees. Decorations go in a namespace scoped to the right window (`nvim__ns_set`), so the file's other windows stay clean.
- **Own tab page.** IntelliJ opens a diff in an editor tab, and differ and diffview open tabs too. `show(win, spec)` covers the embedded case of `git-changes-tree`.
- **Approved look, real windows.** Neovim always draws a separator between two vertical windows. Column 40 is that separator, blank (`fillchars` `vert: `), so the `╱` padding and the wavy fold rows have a one-cell gap there. Everything else is cell for cell `diff2_aligned`.
- **Context 4** (IntelliJ's `CONTEXT_RANGE` default) instead of the mockup's 3/2. The screen therefore starts at line 49 and is 100x30.
- **Bufferline and statusline rows** are the real ones and are not asserted. The screen scenario checks rows 2–29.
- **Highlight groups per kind.** PLAN's single names are split where a cell's colours differ by kind: `DiffViewArrow{Add,Change,Delete}`, `DiffViewGutter{Add,Change,Delete}` (line number and checkbox on a tinted row), and `DiffViewFoldText` for the fold label.
- **An unchanged file opens nothing** and notifies `No changes`, rather than showing an empty diff.
- **Engine fallback** (`too_big`/`timed_out`) is shown in the right winbar instead of a notification, since background work is silent (rule 8.4).
- **`]f` is defined here** with a callback hook, so `git-changes-tree` only supplies the list.
