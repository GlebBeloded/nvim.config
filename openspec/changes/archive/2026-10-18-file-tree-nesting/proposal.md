## Why

Kind: feature
Depends: file-tree-ops

The new project tree (`file-tree-view`) lists every file of a folder flat, so a Go package shows each source file next to its test, mock and stringer files, and a web folder shows `package.json` between four lock and rc files. IntelliJ and VS Code nest such files under their parent ("file nesting"), so a folder reads as its real units. The user is used to IntelliJ and asked for the full recommended rule set, programmable, with regular expressions as the first iteration, and for fold all / unfold all actions that include the nests.

## What Changes

- **Rules file.** New user-editable `settings/file_tree.json`, versioned in the repo like `settings/keymap.json`. Its `nesting.rules` list holds:
  - pattern rules (a parent pattern and child templates, design.md Decision 2): Lua patterns that match a whole file name, where a child template uses the parent's captures (`${capture}` is the first, `${1}`…`${9}` any), inserted literally;
  - programmable rules `{ "lua": "<module>" }`: the module returns a function that gets the folder path and its file names and returns parent → children.
  - `nesting.enabled` turns nesting off without deleting the rules.
- **Loader** `lua/gleb/file_tree/settings.lua`: reads and validates the file, reloads it when it is written from Neovim, skips a broken rule with a warning and a broken file with an error.
- **Pure engine** `lua/gleb/file_tree/nesting.lua`: one folder's entries + rules → parent → children. One level, same folder, files only; the first rule that claims a file wins; chains (a source map of a compiled file of a TypeScript file) end at the top parent; a claim that would make a cycle is dropped.
- **Default rule set** (Decision 5): Go, protobuf, Go modules and workspaces, TypeScript, TSX, JavaScript, package managers, tsconfig, Python, pyproject, Cargo, Lua specs, git files, README, Makefile.
- **View** (`model.lua`, `render.lua`, `view.lua`): a parent file gets a chevron in the expander column, its nest starts collapsed, children sit one level deeper. `file_tree.toggle_fold` toggles a nest, `file_tree.close_node` closes it from the parent or a child, `file_tree.open` still opens the file, `file_tree.unfold_all` and `file_tree.fold_all` include nests, following the current file opens its nest, and nest state survives refreshes (keys in design.md Decision 6).
- **Git tint:** a parent without its own status takes its children's status, like a folder.
- **Render:** "Proposed — nests under a chevron" (the approved `nest_chevron` screen).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `file-tree`: adds nesting settings, programmable rules, precedence, caching and limits, defaults, rows, per-tab state, actions, git tint and the approved screen; modifies "Project tree folds" so `za`, `zM` and `zR` include nests.

## Impact

- Code:
  - New: `settings/file_tree.json`, `lua/gleb/file_tree/settings.lua`, `lua/gleb/file_tree/nesting.lua`.
  - Changed: `lua/gleb/file_tree/model.lua` (nest children, cache and parent tint), `lua/gleb/file_tree/render.lua` (chevron and nest indent), `lua/gleb/file_tree/view.lua` (per-tab nest state, actions, selection, follow and settings reload), `lua/gleb/file_tree/actions.lua` (existing fold action ids include nests), and `lua/gleb/file_tree/ops.lua` (move migration and child target folders). Actions and keys keep the ids and keys `file-tree-view` gave them.
- Tests:
  - unit: `tests/unit/file-tree/test_nesting.lua` (engine, rule syntax, precedence, Lua rules, the default set as a case table), `tests/unit/file-tree/test_settings.lua` (loader).
  - integration: `tests/integration/file-tree/test_nesting.lua` (rows, per-tab state, actions, follow, refresh, ops, git tint and reload) on the `treeproj` fixture; existing file-tree and picker suites run with nesting disabled through their shared setup.
  - screen: `tests/screen/file-tree/test_nesting.lua` with a byte-identical `tests/screen/file-tree/nest_proposed.ansi` copy of the approved render and real extmark assertions.
- Fixture: `treeproj` in `tests/fixtures/build.sh` (from `file-tree-view`), exactly as design.md Decision 8 lists it.
- Plugins: none added or removed. No plugin offers nesting for a custom tree. neo-tree's own `nesting_rules` only work inside neo-tree, which `tree-diff-cutover` removes.
- Core keymaps: none. The scoped tree keys of `file-tree-view` gain nest behaviour.
- Unchanged scenarios: neo-tree stays the default tree until `tree-diff-cutover`; no neo-tree requirement changes (this change only adds `file-tree` requirements).
- Out of scope:
  - Nesting more than one level deep, or across folders (a Go file with its `testdata/` files).
  - Glob syntax (VS Code `*.go`) and `${basename}`, `${extname}`, `${dirname}` tokens.
  - Renaming or deleting a nest's children together with its parent (IntelliJ asks; here each op acts on its own row).
  - A settings UI and a nesting toggle action; `nesting.enabled` is the switch.
  - Folders as nest parents or children.

## Decision (user, 2026-10-17)

- Decision page: https://claude.ai/artifact/P7naTb7oU7Ke52P1QNkEdH
- Nesting: picked "chevron on the parent file, nests start collapsed" (render `nest_chevron`) and "the full recommended rule set".
- "it should be programmable, Maybe regexp is enough for first iteration".
- "Also I need fold all/unfold all actions in file tree".
- General: "I'm used to Idea".

## Decision (auditor, 2026-10-18, pre-implementation audit)

- Earlier suites: a shared test helper calls `settings.setup({ path = <temp file with nesting.enabled=false> })`, used by the file-tree-view and file-tree-ops integration and screen suites, so F1, G1, G2, `test_project_tree` and `test_project_live` keep passing unchanged. "Project tree folds" becomes a MODIFIED requirement (`za` on a nest parent toggles its nest). A task 0 does this and runs `make test CAPS=file-tree,picker` before any nesting code; extending the fixture never changes files those screens depend on.
- State: `view.expanded_nests` per tab, keyed by the parent's path relative to the root, never in `view.expanded`; not persisted (`expanded.json` unchanged); cleared on reroot and by `zM`; dropped in `draw()` for a parent that is gone, not a file, or childless; migrated with folder and file rename/move in every view of the root. Engine entries use the shipped `{ name, path, kind }`. Broken-rule warnings follow the design (once per rule per load).
- Performance: the nest map is cached per folder keyed by the `fs.scan` table (weak keys) plus a settings generation bumped by reload; git redraws never re-run rules or Lua functions; a template literal after substitution is a hash lookup; a unit test bounds 16 rules on 5000 files at ≤50 ms; the 5000-row caps count nest children.
- Tint: a parent without its own status takes the strongest status among its listed children via a helper shared with `folder_status`'s strength table and renamed/deleted→modified folding; a deleted, unlisted child does not tint its parent (pinned by a scenario).
- Ops and follow: one view helper `select_path(path)` expands folders, then the nest, then moves the cursor; follow, reveal, add, rename and paste use it with `fs.normalize`d paths; the target folder on a child row is `dirname(row.path)`. Scenarios: rename or paste into a collapsed nest; a folder rename with an expanded nest inside; Visual `d` over a collapsed parent (parent only); nest state isolated between two tabs; follow under a symlinked `/private/var` root; the settings `BufWritePost` matched through `fs.normalize`. The screen case asserts text verbatim against a byte-identical copy of `nest_proposed.ansi` kept under `tests/screen/file-tree/` (a test never reads `openspec/changes/`, which archiving moves) and real extmark groups (no hand-made mask, no self-blessed screenshot). Split task 4 into 4a (rows, view state, refresh) and 4b (settings: invalid, off, reload, symlinked path), task 5 into 5a (keys and the row cap) and 5b (follow/reveal and ops interplay).

## Agent decisions

- **Lua patterns** are the regular expressions (Decision 2): pure Lua, captures built in, and no doubled backslashes in JSON. vim.regex has no capture API of its own, and globs can't capture more than one `*`.
- **Programmable rules** are entries of the same list (`{ "lua": "<module>" }`), so a function rule has a place in the priority order. A global function (`vim.g`) couldn't.
- **Precedence:** the first rule wins, as in the user's list order. A shared child (`price.d.ts` of `price.ts` and `price.js`) goes to the earlier rule. VS Code shows such a file under both parents. Here every file has exactly one row, so the G ops stay unambiguous.
- **Chains** end at the top parent, as in VS Code (`ExplorerFileNestingTrie`).
- **Git tint:** a parent without its own status takes its children's status, whether the nest is open or closed. So a collapsed nest never hides a change, and parents behave like folders. Its own status wins (`tax.go` added stays green).
- **Keys:** `<CR>`/`o`/`l` keep opening the parent file, and `za` and `h` act on the nest. In IntelliJ, Enter opens and the arrows expand, and `l` is open in every tree here.
- **Nested child names** use the plain file groups. The mockup's dimmed `grey2` children never show in the approved screen, and IntelliJ draws them like other files.
- **Render chrome:** the statusline names the tree's filetype `gleb-file-tree`, where the approved mockup said `neo-tree`. The tree rows are unchanged.
