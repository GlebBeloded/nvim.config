## Why

Today `gr` opens a flat list of references in the shared picker. That list can't hide test code, doesn't group usages by where they live, and can't show the code around a usage before you jump to it. The user wants a JetBrains-style Find Usages view instead: a grouped tree beside a code preview, centred and almost full screen.

Kind: feature
Depends: references-test-scope

## What Changes

- New `lua/gleb/references/`: `gr` opens a **Find Usages view** for the symbol under the cursor. It works with any attached LSP client that supports `textDocument/references`.
- **Layout:**
  - A centred float covering the editor except 2 columns on each side and the bufferline/statusline rows.
  - Tree on the left (45% of the inner width), preview on the right, joined divider.
  - Title `Usages of <symbol> · <count>` in the top border.
  - Hint row inside the window under a joined rule (rule 8.9).
  - Below 80 editor columns the preview starts hidden, and the window shrinks to its content (widest row or hint) and stays centred.
- **Tree:**
  - Levels: test scope (`Production` / `Test`), then one folder row holding the folder's full path relative to the working directory, then usage rows `<file>:<line>`. The preview shows the code.
  - Group rows show their usage count, and every group folds.
  - The declaration is not a usage.
- **Icons and colours** (Nerd Font):

  | Row | Glyph | Icon colour |
  |---|---|---|
  | Production | oct-rocket `U+F427` | aqua |
  | Test | oct-beaker `U+F499` | yellow |
  | Folder | md-folder_outline `U+F0256` | grey |
  | File | the filetype's devicon | the devicon's colour |

  - Each label is a paler shade of its icon colour: `mix(icon, fg1, 0.7)`, computed from the gruvbox-material palette (rule 8.7).
  - Counts and `:<line>` use [PickerSecondary].
- **Grouping controls** (persisted across sessions):
  - `t` cycles the tests mode: `grouped` → `hidden` (test usages removed) → `mixed` (no scope level; test usages carry a right-aligned beaker `test` tag).
  - `f` toggles `Folders`. When off, rows show the path relative to the working directory.
  - The hint row shows the current state: `Tests: grouped t · ● Folders f · Preview P · Open ↩`.
- **Preview:**
  - Shows the lines around the selected usage, centred, with line numbers.
  - Uses **the same syntax highlighting a regular buffer of that filetype gets**: treesitter when its parser is installed, otherwise the Vim syntax file.
  - The usage's line number uses [CursorLineNr], and every usage of the symbol in that file is marked [Search].
  - Text comes from the loaded buffer when there is one, otherwise from disk.
  - It never loads a buffer, attaches a client or creates a swap file.
- **Keys:** registry actions scoped to the view, with keys in `settings/keymap.json`.
  - `<CR>` opens the usage, or folds a group.
  - `za` folds a group.
  - `t` and `f` are the grouping controls.
  - `P` toggles the preview.
  - `q` and `<Esc>` close the view.
  - Opening a usage closes the view and puts the cursor on it. Closing returns to the window the view was opened from.
- **Empty results:** `No usages found`, or `No LSP references support` when no attached client supports references. Both are INFO notifications, and no window opens.

## Capabilities

### New Capabilities
- none; the `references` capability is created by `references-test-scope`.

### Modified Capabilities
- `references`: the view, layout, tree, icons, grouping controls, preview, keys and empty results (ADDED requirements).
- `keymaps`: `gr` opens the Find Usages view ("LSP actions and navigation", scenario "gr bound to Telescope references").
- `lsp`: "Go references workflow" lists usages in the view without the declaration, and opens a usage from the tree.
- `file-tree`: "gr keeps its global meaning in git status tree" now names the Find Usages view.

## Impact

- Code:
  - New: `lua/gleb/references/` (`init`, `request`, `tree` (pure), `view`, `preview`, `icons`, `state`), and `openspec/changes/references-view/renders/*.ansi` (approved renders with real glyphs and colours).
  - Changed: `lua/gleb/keymaps/actions.lua` (`lsp.references`) and `settings/keymap.json` (view keys).
  - Removed: the old references source in `lua/gleb/picker/actions.lua`.
- Tests:
  - unit: tree for every tests mode and folders combination, the paler-shade colour mix;
  - integration: open, grouping and its persistence, preview highlighting equal to a regular buffer, no buffer or client left behind, keys, empty results;
  - screen: V1–V4;
  - e2e: real `gr` in the `gomod` fixture, then `t`, then opening a usage, each step compared with its render.
- Plugins: none (nvim-web-devicons is already used). Core keymaps: `gr` keeps its key and opens the new view.
- Unchanged scenarios. The view's `q`, `<CR>`, `<Esc>`, `f` and `t` are buffer-local to the view filetype, so these still hold:
  - `ai: Menu ignores other keys`
  - `autocommands: q closes special buffers through an action`
  - `git: q closes diffview from file panel`
  - `git: Enter confirms message`
  - `git: Enter on empty buffer does nothing`
  - `git: Enter on placeholder does nothing`
  - `git: Enter drops comment lines`
  - `git: q discards popup`
  - `git: ]f steps to the next changed file in differ`
  - `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press` (`<C-CR>` is untouched)
- Out of scope: read/write grouping (`references-usage-kind`), per-language server checks (`references-languages`), code rows, a function level, typing a filter, and call hierarchy.

## Decision (user, 2026-10-16)

- **Request:** "find references UI … conditional grouping on read/write references, excluding tests. Grouping references by path (also conditional). It should show lines around selected usage. Should be in the middle of the screen almost taking full screen." The model is the JetBrains Find tool window with its preview.
- **Languages:** "It should work [for] all supported languages in config (where applicable), not only go."
- **Rows and preview:** "we see usage on the right, so we can just use file.go:{line_num}". The preview "should reuse same syntax highlighting as regular buffer of that file type". The controls must be clear and not duplicated.
- **Icons:** Production rocket (alternative 4), tests yellow beaker (4), folder outline (2). Label paleness 0.7. Yellow reads, blue writes.
- **Folders:** no nested folder rows. One row per folder with its full path, as in GoLand.
- **Scope:** "we can just start on first iteration", so no code-row style and no function level yet.
- **Narrow layout:** without the preview the window "doesn't need to be that big". It shrinks to its content.
- The approved renders are V1–V4 in design.md.

## Agent decisions

- Defaults: tests `grouped` and folders on, so nothing is hidden on first use.
- The declaration is excluded, as in JetBrains. The title names the symbol.
- The view is navigated, not searched, so it doesn't use mini.pick's prompt. It reuses the picker highlight groups and the rule 8.9 frame.
