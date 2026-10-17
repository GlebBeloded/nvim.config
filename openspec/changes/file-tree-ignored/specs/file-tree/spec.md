## ADDED Requirements

### Requirement: File tree ignored entries
An entry SHALL be ignored when git lists it as an untracked ignored path, when it lies below an ignored folder, or when it matches a glob of the `ignore` list in `settings/file_tree.json`: without `/` by name at any depth, with `/` by path from the tree root. Tracked files SHALL never be ignored. While Show Ignored is off, ignored entries SHALL be left out before nesting, with no hint row. `.git` SHALL never be listed.

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
- **WHEN** the tree shows the `treeproj` fixture, the line `notes.md` is appended to `.gitignore` in a buffer, and `:write` is run
- **THEN** within 2 s `notes.md` is no longer listed

#### Scenario: Hidden ignored file is not revealed
- **WHEN** Show Ignored is off, the tree cursor is on `invoice.go`, and `:edit .env` runs in the editor window
- **THEN** the tree rows are unchanged and the tree cursor is still on `invoice.go`

#### Scenario: Ignore patterns apply outside a git repository
- **WHEN** the tree opens on a temporary folder that is not inside a git repository, holding `main.go` and `scratch.swp`, with the settings file setting `"ignore": ["*.swp"]`
- **THEN** `main.go` is listed, `scratch.swp` is not, no `git ls-files` command is spawned, and no notification is shown

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

### Requirement: File tree ignored look
A shown ignored entry SHALL draw its name and its file or folder icon with `FileTreeIgnored`, defined from the palette as grey0 italic. Its expander SHALL keep `FileTreeExpander`. An ignored entry SHALL get no git colour and SHALL never tint its folder.

#### Scenario: Ignored rows are grey italic
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture
- **THEN** the icon and name cells of the `bin`, `node_modules` and `.env` rows are drawn with `FileTreeIgnored`, and `FileTreeIgnored` has the palette's grey0 foreground and `italic = true`

### Requirement: File tree ignored folders
The tree SHALL never list or watch an ignored folder's content until the user expands it. `file_tree.unfold_all` SHALL leave ignored folders collapsed. Entries below an expanded ignored folder SHALL be ignored without a git command, and no git status request SHALL name them.

#### Scenario: Unfold all leaves ignored folders collapsed
- **WHEN** `I` is pressed in the tree on the `treeproj` fixture, then `zR`
- **THEN** `bin` and `node_modules` show the collapsed expander, and neither `server` nor `left-pad` is listed

#### Scenario: Expanded ignored folder lists ignored children
- **WHEN** Show Ignored is on, `vim.system` calls are recorded, and `za` is pressed on the `bin` row
- **THEN** `server` is listed under `bin` with its name drawn in `FileTreeIgnored`, and no recorded call during the expansion runs `git`

### Requirement: File tree ignored screen
After Show Ignored, the tree SHALL look like the approved render.

#### Scenario: Show Ignored matches the approved render
- **WHEN** the editor is 100x30 and the tree is in the state of `file-tree: File tree nests match the approved render`, with `web` and `web/src` expanded, and `I` is pressed
- **THEN** the screen matches the approved render "Proposed — after Show Ignored"
