## Why

Kind: feature
Adopt: loop/file-tree-ops-20261018-042709
Depends: file-tree-view

The project tree from `file-tree-view` can only browse. The user edits files from the tree every day: add, rename, delete, copy and move. They use neo-tree's operations today (the `file-tree` spec's "Common tree edit mappings"). neo-tree's prompts are nui inputs at the cursor row, outside the shared picker frame (Current renders in design.md). Its renames never tell the language servers, so imports are not updated the way IntelliJ's rename updates them.

## What Changes

- **Operations** in `lua/gleb/file_tree/ops.lua`, as actions in `file_tree/actions.lua` (category `Project`, filetype `gleb-file-tree`), with keys in `settings/keymap.json`:
  - `file_tree.add` `a`: create a file, or a folder when the name ends in `/`. Missing parent folders are created. A new file opens in the editor window.
  - `file_tree.rename` `r`: rename a file or folder. Loaded buffers follow, through Neovim's `vim.lsp.util.rename`.
  - `file_tree.delete` `d` (also Visual): confirm, then move to the macOS Trash with `trash -s`. Without that command, the entries are deleted permanently after the same confirmation. Unmodified buffers of deleted files are closed, and their windows stay.
  - `file_tree.copy` `c`, `file_tree.cut` `x` (both also Visual), `file_tree.paste` `p`:
    - Paste goes into the folder under the cursor.
    - A copy whose name already exists asks for a new name (`invoice_copy.go`).
    - A cut moves like a rename.
  - `file_tree.refresh` `R`: rescan the expanded folders and rerun git status.
- **Language servers:**
  - A rename or move first sends `workspace/willRenameFiles` to every client whose `workspace.fileOperations.willRename` filters match. Their workspace edits are applied (for example, imports), waiting at most 1000 ms.
  - Then the files move.
  - Then `workspace/didRenameFiles` goes to the matching `didRename` clients.
- **Prompts** use the shared picker frame (rule 8.9) through a new `lua/gleb/picker/input.lua`:
  - the title and query in the top border;
  - one preview row with the resulting path;
  - hints right-aligned below the joined rule.

  Delete confirms through `vim.ui.select` (our picker).
- **Errors** are notified at ERROR (rule 8.1):
  - `Already exists: <path>`
  - `Cannot paste <path> into itself`
  - `Create failed: <err>`, `Rename failed: <err>`, `Delete failed: <stderr>`, `Paste failed: <err>`
- **Renders:** Current and Proposed for the add and rename prompts (design.md).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `file-tree`: added requirements for project tree create, rename (with LSP file operations), delete, copy/cut/paste, refresh and their keys and prompts. neo-tree's "Common tree edit mappings" stays until `tree-diff-cutover`.
- `picker`: added "Picker input prompt".

## Impact

- Code:
  - New: `lua/gleb/file_tree/ops.lua`, `lua/gleb/file_tree/paths.lua` (pure helpers), `lua/gleb/file_tree/lsp_files.lua` (will/did rename), `lua/gleb/picker/input.lua`.
  - Changed: `lua/gleb/file_tree/actions.lua`, `settings/keymap.json` (view-scoped keys only), `lua/gleb/file_tree/view.lua` (select a created or pasted entry).
- Tests:
  - unit: `tests/unit/file-tree/test_ops.lua` (target folder, copy names, self-paste check, filter matching).
  - integration: `tests/integration/file-tree/test_project_ops.lua`, `test_project_lsp_rename.lua` (an in-process fake language server: `vim.lsp.start` with a `cmd` function), `tests/integration/picker/test_input.lua`.
  - screen: `tests/screen/file-tree/test_project_ops.lua` (G1, G2).
- Plugins: none. Alternatives considered for the LSP file operations:
  - antosha417/nvim-lsp-file-operations (440 stars, pushed 2026-10-12) hooks into nvim-tree, neo-tree and oil events, not our tree.
  - folke/snacks.nvim `rename` (8.1k stars, pushed 2026-05-25) is a large suite for one helper.

  Neovim's own `vim.lsp.util.rename` already moves files, undo files and buffers. The will/did requests are about 40 lines.
- Core keymaps: none. All keys are buffer-local to `gleb-file-tree`.
- Unchanged scenarios:
  - `diff: Diff view left window is read-only` still holds: file-tree operations never make diff-view buffers modifiable.
  - `diff: Diff view trim policy shows a staged checkbox` still holds: file-tree refresh and file operations do not change diff staging or whitespace policy.
  - `file-tree: a creates a file` and `file-tree: r renames a file` still hold: neo-tree's edit mappings are untouched.
  - `ai: Menu ignores other keys` still holds: the AI menu and its keys are untouched; the new keys exist only in `gleb-file-tree` buffers and the input prompt.
  - `git: ]c steps to the next hunk in differ` still holds: differ and its keys are untouched.
  - `keymaps: Close buffer keeps split layout` still holds: `buffer.close` is untouched; delete only reuses its idea of keeping windows.
  - `keymaps: Paste over selection keeps register` still holds: the global Visual `p` is untouched; the tree's `p` is buffer-local and normal-mode only.
  - `keymaps: Move selected lines down` still holds: the global Visual `J` mapping is untouched.
  - `keymaps: Move selected lines up` still holds: the global Visual `K` mapping is untouched.
  - `keymaps: Alt-j moves selected lines down` still holds: `<A-j>` is untouched.
  - `keymaps: Alt-k moves selected lines up` still holds: `<A-k>` is untouched.
  - `keymaps: Typing p in select mode inserts p` still holds: the tree's Visual keys are `x`-mode only and never Select mode.
  - `lsp: References of a Go function list call sites across packages` still holds: no LSP configuration or client capability changes; only tree renames send file-operation messages.
  - `references: Real key presses switch Calls usages from the level to row tags` still holds: Find Usages keys are untouched.
  - `select: Selection accepts omitted options` still holds: delete calls `vim.ui.select` with items and a prompt, through the unchanged override.
  - `select: Cancelling a code action completes selection` still holds: the `vim.ui.select` override is unchanged.
  - `select: Selection previews the current item` still holds: the `vim.ui.select` override is unchanged.
  - `select: Omitted options open shared selection` still holds: the `vim.ui.select` override is unchanged.
  - `shortcuts: The stack harness shows the screen that blocks Neovim` still holds: no terminal or global shortcut changes.
- Out of scope:
  - `workspace/willCreateFiles`, `didCreateFiles`, `willDeleteFiles` and `didDeleteFiles`.
  - Undo of file operations, drag and drop, and operations from outside the tree (Find Action on an editor buffer).
  - Replacing `vim.ui.input` globally: LSP rename (`<A-r>`) keeps its prompt.

## Decision (user, 2026-10-17)

- "I'm used to Idea".
- File tree: the IntelliJ project view, with add/delete/rename/copy/cut/paste/refresh ("file-tree-ops: add/delete/rename/copy/cut/paste/refresh with buffer renames and LSP workspace/willRenameFiles", the approved plan).

## Decision (auditor, 2026-10-18, pre-implementation audit)

- Move safety: one `ops.move(pairs)` pre-checks every pair before any LSP traffic: the source exists (lstat); the target is absent (case-insensitive, except the source itself); the target is inside the root after normalising (no `..`, absolute paths or empty segments); the same `dev`, else `Rename failed: cross-device`; never the root row (normal or Visual). Then one batched willRename (≤1000 ms total, `on_submit` scheduled after the picker closes), the move, and a stat confirming it before didRename. A case-only rename goes through a temp name. Buffers are renamed by realpath match (symlinked and `/private/var` buffers follow); expanded keys migrate; every view of the root refreshes once per batch.
- Delete safety: `/usr/bin/trash -s` (a module-state override for tests, never a PATH guess); never `rm` after a trash failure; delete the row's own path via lstat, never its realpath. Buffers are wiped only for paths a stat afterwards shows gone, across all tabs; a fallback buffer is never a deleted file. Modified buffers of deleted files stay open but `should_autosave` skips files that no longer exist; the confirm prompt names how many unsaved buffers are affected.
- Paste and create safety: `a dir/` on an existing folder → `Already exists`; a cut onto an existing name → `Already exists`, never an overwrite; a cut into its own parent → no-op; a Copy prompt whose name exists re-prompts with `_copy2`; a folder copy pre-checks the whole destination tree before writing; symlinks are recreated, not followed; a missing clipboard path → `Paste failed: <path>: ENOENT` and the rest continue.
- Scenarios: root-row refusal, `..` escape, case-only rename, symlinked-root buffer rename, `chmod 555` create/rename/fallback-delete, vanished-row rename and delete, two-tab refresh isolation, `<Esc>` focus and `guicursor` restore, expanded-key migration, cut over an existing name, auto-save not resurrecting a deleted file; "R" asserts runs ≥ +1.
- Tasks: the unit file is `test_paths.lua` everywhere; the keys scenario moves into 3; split 4 into 4a (`lsp_files`, fake server, filter units) and 4b (rename/move, buffers, symlink, case-only), and 6 into 6a (copy/paste, conflicts), 6b (cut/move, self-paste), 6c (refresh); 7 asserts text verbatim against byte-identical copies of `g*_proposed.ansi` kept under `tests/screen/file-tree/` (a test never reads `openspec/changes/`, which archiving moves) plus real extmark groups (no hand-made masks, no self-blessed screenshots); a final task for `docs/architecture.md`, `make test CAPS=find-action,actions,file-tree` (incl. `more_results` and the neo-tree `test_tree.lua`) and `make check`. New actions set no `plugin`.

## Agent decisions

- **Trash:** macOS 15+ ships `/usr/bin/trash` (checked: present here, `-s` stops on the first error), so delete is recoverable. Without the command, the same confirmation leads to a permanent delete.
- **Confirmation** always asks, even for one file, as IntelliJ does. The choices are `Move to Trash` (or `Delete` without the command) and `Cancel`.
- **New file opens** in the editor window and takes focus (IntelliJ). A new folder stays selected in the tree.
- **Rename** takes a name relative to the entry's folder. A `/` in it moves the entry into a sub-folder, created when missing.
- **Copy name conflict** asks for a name, prefilled with `<stem>_copy<ext>`, instead of overwriting.
- **The tree clipboard** is the tree's own state, not a register. A cut is cleared after its paste. A copy can be pasted many times.
- **A compact row** (`cmd/server`) stands for its last folder in every operation.
- **Modified buffers** of deleted files stay open, so unsaved text is never lost. Renamed modified buffers are written to the new path by `vim.lsp.util.rename` (`:saveas!`), and auto-save writes them anyway.

## Rejected run
Run on `loop/file-tree-ops-20261018-042709` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] A case-only rename of a symlink row still resolves the realpath, so buffers end up named after a path outside the root. In lua/gleb/file_tree/ops.lua:217-224, `rename_path` takes the case-only branch (`rename_case_only(old, new, buffers_at(old))`) before the `fs_lstat(...).type == "link"` check. `buffers_at` (ops.lua:77-99) matches buffers by realpath, and line 170 renames them to `dirname(logical_old)/basename(new)`.
  
  Probe: `proj/link.txt` is a symlink to `out/target.txt` outside the root. Load the target directly, and also through `link.txt`. Then call `ops.move({{old=root.."/link.txt", new=root.."/Link.txt"}})`. It returns true and the link moves, but both buffers are now named `<tmp>/out/Link.txt`, a path that does not exist outside the root. A `:write` then creates a file beyond the root.
  
  This breaks "Project tree move identity and state" ("rename moves a symlink and not its target … buffers move by logical path"), "operation path safety" and the auditor Decision (act on the row's lstat path, never its realpath).
  
  Why pass 6 missed it: the fix c7a0dfac added the link branch after the case-only branch, and the new test only covers a rename that is not case-only.
  
  Fix: check lstat for a link before the case-only branch. For a link, use `buffers_at_logical_path`, and do the case-only move through a temporary sibling with `fs_rename`. Add a case-only symlink rename to the symlink scenario's test.
  
  [minor] Visual `c`/`x` still leave Visual mode active (ops.lua:58
