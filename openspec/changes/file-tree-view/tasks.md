## 1. Fixture and pure model

Scenarios: `file-tree: Project tree lists folders first in case-insensitive order`, `file-tree: Single-child folders share one row`, `file-tree: Project tree hides the git folder`

- [ ] 1.1 Add `treeproj` to `tests/fixtures/build.sh` (design.md, Fixture: the exact function, the header line and the `case` entry). Write unit cases in `tests/unit/file-tree/test_model.lua`: sort keys, compact chains over entry tables, `.git` filtering, `parse_status` on recorded porcelain v2 `-z` output (types `1`, `2`, `u`, `?`, `?` folder), `folder_status` precedence. Write the three scenarios on a `treeproj` copy through `model.rows` + `fs.lua`. See them fail.
- [ ] 1.2 Add `lua/gleb/file_tree/model.lua` (pure, LuaCATS classes for entries and rows) and `fs.lua` (design Decisions 1–4, 6).
- [ ] 1.3 Run `make test FILE=tests/unit/file-tree/test_model.lua` and see it pass.

## 2. Window, rows and toggle

Scenarios: `file-tree: Project tree opens on the left at width 35`, `file-tree: Project tree toggle closes a focused tree`, `file-tree: Project tree toggle focuses an open tree`, `file-tree: Project tree closes with the last window`, `file-tree: Project tree actions start unbound`, `file-tree: Project tree root row names the project`, `file-tree: Project tree rows have icons and no guides`, `bufferline: tabs start after the open project tree`

- [ ] 2.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua` and `tests/screen/bufferline/test_bufferline_screen.lua` (new case), and see them fail.
- [ ] 2.2 Move the neo-tree setup verbatim from `file_tree/init.lua` to `file_tree/neo_tree.lua`. Make `init.lua` require it, then `view.setup()` (Decision 1). Add `render.lua` (lines, extmarks, highlight groups on `ColorScheme`) and `view.lua` (Decision 9).
- [ ] 2.3 Append `file_tree.toggle` and `file_tree.reveal` to `file_tree/actions.lua`, both unbound. Add the `gleb-file-tree` offset to `bufferline.lua`.
- [ ] 2.4 Run the two files and `make test FILE=tests/integration/file-tree/test_tree.lua` (neo-tree scenarios unchanged), and see them pass.

## 3. Open, close and fold keys

Scenarios: `file-tree: Expanding a compact row shows the last folder's entries`, `file-tree: Project tree Enter toggles a folder`, `file-tree: Project tree Enter opens a file in the editor window`, `file-tree: Project tree h on a file collapses its folder`, `file-tree: Project tree v opens a vertical split`, `file-tree: Project tree s opens a horizontal split`, `file-tree: Project tree t opens a new tab`, `file-tree: Project tree q closes the tree`, `file-tree: Project tree za on a file collapses its folder`, `file-tree: Project tree zM collapses every folder`, `file-tree: Project tree zR expands every folder`, `file-tree: Project tree unfold all stops at the row limit`, `file-tree: Project tree keys come from the keymap file`

- [ ] 3.1 Write these scenarios in `tests/integration/file-tree/test_project_tree.lua`, and see them fail.
- [ ] 3.2 Add the view-scoped actions (`ft = "gleb-file-tree"`, category `Project`) and their keys in `settings/keymap.json` (Decisions 11, 12).
- [ ] 3.3 Remove `file_tree = "neo-tree"` from `ADAPTER_PLUGINS` in `find_action/assign.lua`. Move the adapter fixture action in `tests/integration/find-action/test_assign.lua` from `file_tree.open` to `neo_tree.open`, with every assertion kept.
- [ ] 3.4 Run the file and `make test CAPS=find-action`, and see them pass.

## 4. Git colours

Scenarios: `file-tree: Project tree colours changed files`, `file-tree: Project tree folders take the strongest status below them`, `file-tree: Project tree colours renamed and conflicted files`, `file-tree: Project tree reads git status without optional locks`, `file-tree: Project tree outside a repository has no git colours`, `file-tree: Project tree runs git status once per burst`, `file-tree: Project tree highlight colours come from the palette`

- [ ] 4.1 Write these scenarios in `tests/integration/file-tree/test_project_git.lua` (each on its own `treeproj` copy), and see them fail.
- [ ] 4.2 Add `git.lua` (Decision 5: debounce, single flight, generations, `state.runs`, `state.last_cmd`) and the folder tint in `render.lua` (Decision 6, 13).
- [ ] 4.3 Run the file and see it pass.

## 5. Following, live updates and persistence

Scenarios: `file-tree: A compact chain splits when a folder gains an entry`, `file-tree: Project tree follows the current file`, `file-tree: Project tree ignores files outside the root`, `file-tree: Project tree reveal focuses the current file`, `file-tree: Project tree reveal tolerates a deleted file`, `file-tree: Project tree shows files created outside Neovim`, `file-tree: Project tree recolours a written file`, `file-tree: Project tree recolours after staging outside Neovim`, `file-tree: Project tree watchers stop when the tree closes`, `file-tree: Project tree re-roots on a cwd change`, `file-tree: Project tree expanded folders persist per root`, `file-tree: Project tree drops a stored folder that is gone`

- [ ] 5.1 Write these scenarios in `tests/integration/file-tree/test_project_live.lua`. External changes run with `vim.system` (`touch`, `git add`), never through the tree. See them fail.
- [ ] 5.2 Add `watch.lua` (Decision 7) and `expanded.lua` (Decision 10). Add the follow, reveal, `DirChanged` and `QuitPre` autocmds in `view.lua` (Decisions 8, 9).
- [ ] 5.3 Run the file and see it pass.

## 6. Approved render

Scenarios: `file-tree: Project tree matches the approved render`

- [ ] 6.1 Write the screen case in `tests/screen/file-tree/test_project_tree.lua`:
  - the child's `HOME` is a temp dir, with `F.copy("treeproj", HOME .. "/work/billing")`;
  - the ignored entries are deleted, and LSP and diagnostics are off;
  - it follows the scenario's steps;
  - it asserts `H.expect_screenshot` and `H.expect_screen_colors` for the tree window, with the mask and legend of "Proposed F1" (real glyphs in the screenshot).

  See it fail.
- [ ] 6.2 Adjust `render.lua` until it passes. Compare `make render` (a temporary case like the design's) with `renders/f1_proposed.ansi`.
- [ ] 6.3 Run `make check`.
- [ ] 6.4 Update the `file_tree/` row of the module map in `docs/architecture.md`: the project tree beside neo-tree until `tree-diff-cutover`.
