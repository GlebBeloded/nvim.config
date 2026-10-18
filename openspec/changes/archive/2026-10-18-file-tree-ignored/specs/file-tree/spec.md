## MODIFIED Requirements

### Requirement: Project tree git colours
The tree SHALL read status asynchronously with `git --no-optional-locks -C <root> status --porcelain=v2 -z --untracked-files=normal --ignored=matching` and colour names by status. Ignored records SHALL be separate from file and folder status. A folder SHALL take the strongest descendant status: conflict, modified, added, untracked. Outside a repository it SHALL draw no git colours and run no git command.

#### Scenario: Project tree colours changed files
- **WHEN** the project tree shows the expanded `internal/billing` folder and the root files of a copy of the `treeproj` fixture
- **THEN** `invoice.go` is drawn with `FileTreeGitModified`, `tax.go` with `FileTreeGitAdded`, `notes.md` with `FileTreeGitUntracked`, and `discount.go` and `go.mod` with `FileTreeFileName`

#### Scenario: Project tree folders take the strongest status below them
- **WHEN** in a copy of the `treeproj` fixture `docs/api.md` is created and staged and `scratch/todo.txt` is created untracked, and the tree shows the root
- **THEN** `internal` and `web` are drawn with `FileTreeGitModified`, `docs` with `FileTreeGitAdded`, `scratch` with `FileTreeGitUntracked`, `cmd/server` with `FileTreeFolderName`, and the root name with `FileTreeRoot`

#### Scenario: Project tree colours renamed and conflicted files
- **WHEN** in a copy of the `treeproj` fixture `README.md` is renamed to `READ.md` with `git mv`, `go.mod` is left unmerged by a failed `git merge`, and the tree shows the root
- **THEN** `READ.md` is drawn with `FileTreeGitRenamed` and `go.mod` with `FileTreeGitConflict`

#### Scenario: Project tree reads git status without optional locks
- **WHEN** the project tree opens in a copy of the `treeproj` fixture
- **THEN** `require("gleb.file_tree.git").state.last_cmd` equals `{ "git", "--no-optional-locks", "-C", <root>, "status", "--porcelain=v2", "-z", "--untracked-files=normal", "--ignored=matching" }`

#### Scenario: Project tree outside a repository has no git colours
- **WHEN** the project tree opens in a temp directory outside any git repository that holds `a.txt`
- **THEN** `a.txt` is drawn with `FileTreeFileName` and no notification is emitted

#### Scenario: Project tree runs git status once per burst
- **WHEN** the project tree is open and 20 files are written into the root within 50 ms
- **THEN** after 1000 ms all 20 rows exist and `require("gleb.file_tree.git").state.runs` grew by at most 2

## ADDED Requirements

### Requirement: File tree ignored entries
An entry SHALL be ignored when porcelain-v2 marks it `!`, its parent is ignored, or it matches `settings/file_tree.json` `ignore`: patterns without `/` by name at any depth and patterns with `/` from the tree root. Tracked files, the tree root and its ancestors SHALL not be ignored. With Show Ignored off, ignored entries SHALL be removed before nesting with no hint. `.git` SHALL never be listed.

#### Scenario: Ignored entries are hidden by default
- **WHEN** `file_tree.toggle` opens the tree on the `treeproj` fixture with no saved state, and `web` is expanded
- **THEN** no row is `bin`, `node_modules`, `.env` or `.git`, the direct children of `web` are listed as exactly `src` and `package.json`, and no row mentions hidden or ignored entries

#### Scenario: Tracked files matching gitignore stay listed
- **WHEN** in a copy of the `treeproj` fixture `internal/billing/audit.log` is created and added with `git add -f`, `internal/billing/debug.log` is created untracked, and the tree shows `internal/billing`
- **THEN** `audit.log` is listed with the `FileTreeFileName` group, not `FileTreeIgnored`, and `debug.log` is not listed

#### Scenario: Settings ignore patterns hide entries
- **WHEN** the settings file sets `"ignore": ["*.swp", "web/src/*.d.ts"]`, `notes.md.swp` and `cmd/server/main.go.swp` exist in a copy of the `treeproj` fixture, the tree shows `cmd/server` and `web/src`, and the `price.ts` nest is expanded
- **THEN** neither `.swp` file is listed, `price.d.ts` is not listed, and the `price.ts` nest lists only `price.test.ts`

#### Scenario: Ignored nest children leave no chevron
- **WHEN** the settings file sets `"ignore": ["package-lock.json"]` and the tree shows `web`
- **THEN** `package.json` is listed without a chevron and `package-lock.json` is not listed

#### Scenario: Editing gitignore updates ignored entries
- **WHEN** the tree shows the `treeproj` fixture with its cursor on `notes.md`, the line `notes.md` is appended to `.gitignore` in a buffer, and `:write` is run
- **THEN** within 2 s `notes.md` is no longer listed and the tree cursor is on `Makefile`, the nearest listed row above

#### Scenario: Hidden ignored file is not revealed
- **WHEN** Show Ignored is off, the tree cursor is on `invoice.go`, and `:edit .env` runs in the editor window
- **THEN** the tree rows are unchanged and the tree cursor is still on `invoice.go`

#### Scenario: Ignore patterns apply outside a git repository
- **WHEN** the tree opens on a temporary folder that is not inside a git repository, holding `main.go` and `scratch.swp`, with the settings file setting `"ignore": ["*.swp"]`
- **THEN** `main.go` is listed, `scratch.swp` is not, no `git ls-files` command is spawned, and no notification is shown

#### Scenario: Nested gitignore and negation are honoured
- **WHEN** a copy of `treeproj` has `web/.gitignore` containing `generated/*` and `!generated/keep.ts`, both `web/generated/drop.ts` and `web/generated/keep.ts` exist untracked, and the tree shows `web/generated`
- **THEN** `keep.ts` is listed and `drop.ts` is not listed

#### Scenario: Tree root inside an ignored folder stays visible
- **WHEN** the tree root is `web/node_modules/left-pad` in a copy of the `treeproj` fixture
- **THEN** the root row and `index.js` are listed and neither is marked ignored

#### Scenario: Folder with only ignored content stays listed
- **WHEN** a copy of `treeproj` has an untracked `generated` folder containing only `debug.log`, and the root row is expanded
- **THEN** `generated` is listed, expanding it lists no child, and `generated` is not marked ignored

#### Scenario: Ignored sets follow normalized roots across tabs
- **WHEN** two tabs show the same repository through a symlink-normalized `/private/var` path, one rooted at the repository and one at `web/`, with Show Ignored off
- **THEN** both tabs hide their ignored entries and the `web/` tab hides `node_modules`

### Requirement: File tree hidden-path gate
A hidden ignored target SHALL not expand folders or nests, write `expanded.json`, or move the tree cursor when reached by follow, reveal, create selection or move refresh. Ignoring SHALL win over nest reveal. If refresh or toggling removes the selected row, the cursor SHALL move to the nearest listed row above.

#### Scenario: File under hidden node_modules is not revealed
- **WHEN** Show Ignored is off, the tree cursor is on `web/src/cart.tsx`, and `:edit web/node_modules/left-pad/index.js` runs in the editor window
- **THEN** no folder or nest expands, `expanded.json` is unchanged, and the tree cursor stays on `cart.tsx`

#### Scenario: Created or renamed ignored target is not selected
- **WHEN** Show Ignored is off and file-tree create or rename completes at `web/node_modules/left-pad/new.js`
- **THEN** `select_created` or `refresh_moved` does not expand `web/node_modules`, persist expansion, or select the hidden target; if the selected rename source vanishes, the cursor moves to the nearest listed row above

### Requirement: File tree Show Ignored action
The toggle action `file_tree.show_ignored` (title "Show Ignored", category Project, filetype `gleb-file-tree`) SHALL show or hide ignored entries in every open tree. It SHALL be bound to `I` through `settings/keymap.json` and listed in Find Action with its state. Its state SHALL persist as `show_ignored` in `stdpath("state")/file_tree/view.json` and be read when a tree opens. The default SHALL be off.

#### Scenario: I toggles ignored entries
- **WHEN** the tree shows the `treeproj` fixture with `web` expanded, and `I` is pressed twice
- **THEN** after the first press `bin` is listed between `.github/workflows` and `cmd/server`, `node_modules` before `src` under `web`, and `.env` before `.gitignore`; after the second press none of them is listed

#### Scenario: Show Ignored is a Find Action toggle
- **WHEN** `<M-A>` opens Find Action from the tree window, `Show Ignored` is typed, and Enter is pressed
- **THEN** the row shows the on glyph `●`, the palette stays open, and after it is closed the tree lists `bin`, `node_modules` and `.env`

#### Scenario: Show Ignored persists
- **WHEN** `I` is pressed in the tree, the tree is closed with `q`, and `file_tree.toggle` opens it again
- **THEN** `bin` is listed, and `stdpath("state") .. "/file_tree/view.json"` decodes to a table with `show_ignored = true`

#### Scenario: Saved Show Ignored state is restored
- **WHEN** `stdpath("state") .. "/file_tree/view.json"` holds `{"show_ignored":true}` before `file_tree.toggle` first opens the tree on the `treeproj` fixture
- **THEN** `bin` and `.env` are listed

#### Scenario: Hiding the selected ignored row moves upward
- **WHEN** Show Ignored is on, the tree cursor is on `node_modules`, and `I` is pressed
- **THEN** ignored rows disappear and the cursor moves to the nearest listed row above the former `node_modules` row

### Requirement: File tree ignored look
A shown ignored entry SHALL draw its name and its file or folder icon with `FileTreeIgnored`, defined from the palette as grey0 italic. Its expander SHALL keep `FileTreeExpander`. An ignored entry SHALL get no git colour and SHALL never tint its folder.

#### Scenario: Ignored rows are grey italic
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture
- **THEN** the icon and name cells of the `bin`, `node_modules` and `.env` rows are drawn with `FileTreeIgnored`, and `FileTreeIgnored` has the palette's grey0 foreground and `italic = true`

#### Scenario: Settings-ignored entries do not tint folders or nests
- **WHEN** settings ignore an untracked `cmd/server/main.go.swp` and an untracked `cmd/server/main_mock.go`, and the tree shows `cmd/server` before and after Show Ignored is enabled
- **THEN** `cmd/server` and the `main.go` nest parent are not drawn with `FileTreeGitUntracked`

### Requirement: File tree ignored folders
The tree SHALL never scan or watch an ignored folder until the user expands it. `file_tree.unfold_all` SHALL leave ignored folders collapsed. Expanded children SHALL inherit ignored state without another git request. Filtering SHALL precede nesting; compaction SHALL not enter or cross an ignored folder. Row limits SHALL count listed rows only.

#### Scenario: Unfold all leaves ignored folders collapsed
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture, then `zR`
- **THEN** `bin` and `node_modules` show the collapsed expander, and neither `server` nor `left-pad` is listed

#### Scenario: Expanded ignored folder lists ignored children
- **WHEN** Show Ignored is on, `vim.system` calls are recorded, and `za` is pressed on the `bin` row
- **THEN** `server` is listed under `bin` with its name drawn in `FileTreeIgnored`, and no recorded call during the expansion runs `git`

#### Scenario: Ignored folders do not compact or consume unfold budget
- **WHEN** Show Ignored is on, `web/node_modules` is collapsed, and `file_tree.unfold_all` runs near its row limit
- **THEN** the listed row is `node_modules`, not `node_modules/left-pad`, it stays collapsed, and its hidden descendants do not count toward the row limit

### Requirement: File tree first paint
For a git-backed tree whose watcher has established `toplevel`, the first status request SHALL skip debounce and drawing SHALL wait for its result or 300 ms, whichever comes first. Later refreshes and trees outside git SHALL not wait.

#### Scenario: First paint waits for ignored status
- **WHEN** a git-backed `treeproj` tree opens with status completing within 300 ms
- **THEN** its first drawn frame omits `bin`, `web/node_modules` and `.env`

### Requirement: File tree ignored screen
After Show Ignored, the tree SHALL look like the approved render.

#### Scenario: Show Ignored matches the approved render
- **WHEN** the editor is 100x30 and the tree is in the state of `file-tree: File tree nests match the approved render`, with `web` and `web/src` expanded, and `I` is pressed
- **THEN** the screen matches the approved render "Proposed — after Show Ignored"
