## Why

Kind: feature

Depends: git-committed-signs

The changes panel only shows uncommitted work (HEAD → working tree). On a feature branch the user also wants to
review what is already committed: the whole branch against its base, like a pull request diff, in purple, and
each commit on its own. The user chose tabs in the existing panel, cycled by Cmd+G, over a second tree or one
mixed tree.

## What Changes

- **Tab strip.** The changes panel's winbar shows its tabs as pills, `Local <n>` and `Branch <n>`, the active one
  coloured (`ChangesTabLocal` blue, `ChangesTabBranch` purple), the others `ChangesTabInactive`. The strip is an
  ordered tab list in `lua/gleb/git/changes/tabs.lua`, so `pr-comments-view` appends a third tab (`Comments`)
  without changing the cycle code. The tree rows of the Local tab are unchanged.
- **Branch tab only with a base.** It exists when `git-branch-base` resolves a base and merge-base for the
  current branch. On the default branch (`main`, `master` or the branch `origin/HEAD` names) there is no
  Branch tab: the panel shows `Local` alone.
- **Cmd+G cycle** (`changes.review`, `<A-g>`): with the panel closed, it opens on Local, or on Branch when
  nothing is uncommitted and a Branch tab exists; with the panel open, it moves to the next tab, and after the
  last tab it closes the panel and its diff view. Local → Branch → close on a feature branch, Local → close on
  the default branch.
- **Branch tab, files view** (default): header `<PR icon> #482 feat/tax → main` (`feat/tax → main` without a
  pull request), `3 commits · merge-base 4ccefde`, then the files changed from the merge-base to HEAD as a
  tree (compacted directories, the Local tab's nesting), names in purple (`ChangesCommittedFile`), `+a -r`
  stats. No checkboxes, no staging.
- **Branch tab, commit view**: `c` (`changes.toggle_commits`) switches to an `All changes  <n> files` row
  followed by the branch commits newest first (`<hash> <subject> <age>`); expanding a commit lists its files.
  `c` again returns to the files view.
- **Hint row.** Under a rule on the panel's last two rows: `Commits c · Next tab ⌘G` in the files view,
  `Files c · Next tab ⌘G` in the commit view, keys read from `settings/keymap.json`.
- **Branch diffs** open in the panel's diff view: merge-base vs HEAD for a file row, `<commit>^` vs `<commit>`
  for a commit's file, both sides read-only, labels `4ccefde · main` / `e325463 · HEAD` (commit:
  `07cb52e · parent` / `e325463 · <subject>`), drawn in purple through a new `committed` spec field of the
  diff view (`DiffViewCommitted`, `DiffViewCommittedWord`, `DiffViewGutterCommitted`, `DiffViewArrowCommitted`).
- **Find Action entries** (no keys): `changes.show_local`, `changes.show_branch`, `changes.show_branch_commits`.
- **State per repository** while Neovim runs: the last tab, the commit view and fold states, so
  `changes.toggle` reopens where the user left off.
- **Fixture** `billing-branch`: the `billing` fixture as `main` plus a `feat/tax` branch with three commits and
  uncommitted edits (design.md, Decision 8).

## Capabilities

### New Capabilities

- none

### Modified Capabilities

- `git`:
  - Added: "Changes panel tabs", "Changes tab cycle", "Branch tab files", "Branch tab commit view", "Branch tab
    hint row", "Branch tab diffs", "Branch tab refresh", "Changes tab actions", "Changes tab state".
  - Modified (copied whole): "Changes panel review" (Cmd+G now cycles tabs instead of focusing an open panel;
    its two scenarios are unchanged), "Changes panel diff view" and "Changes panel screen" (their render
    scenarios now name this change's "Proposed — Local only on main", because the strip moves the tree one row
    down; every other scenario is unchanged).
- `diff`: added "Diff view committed layer".
- `bufferline`: modified (copied whole) "Tabline offset for the project tree": its scenario "tabline over the
  changes panel matches the approved render" takes the panel columns of rows 2-4 from this change's
  "Proposed — Local only on main", because the strip now fills the panel's first row; the tabline row is
  unchanged.

## Impact

- Code: new `lua/gleb/git/changes/{tabs,branch,hint}.lua`; changed `git/changes/{init,view,render,git,actions,
  highlights}.lua`, `diff/view/{init,render,highlights}.lua` (the `committed` spec field), `settings/keymap.json`
  (`changes.toggle_commits` on `c`), `tests/fixtures/build.sh` (`billing-branch`), `tests/render/cases.lua`
  (`changes-branch` case).
- Uses: `gleb.git.base` (base, merge-base, PR number, default-branch rule) from `git-branch-base`; the shared
  tree component `lua/gleb/ui/tree/` and its fold keys from `fix-tree-folding`; the purple palette rule of
  `git-committed-signs`.
- Tests: unit `tests/unit/git/test_changes_tabs.lua` (cycle rules, age and summary wording, commit parsing);
  integration `tests/integration/git/test_changes_tabs.lua`, `tests/integration/diff/test_committed.lua`;
  screen `tests/screen/git/test_changes_tabs.lua` and the two updated panel screenshots; e2e Cmd+G cycle.
- Plugins: none added, removed or upgraded. diffview.nvim (already installed, for merges and history) can show
  `origin/main...HEAD`, but in its own tab layout, outside the panel and the owned diff view the user reviews
  with; design.md, Decision 3.
- Core keymaps: `<A-g>` keeps its action; `changes.review` changes behaviour when the panel is already open
  (next tab or close, instead of focus). New view-local key `c` in `gleb-changes`.
- Unchanged scenarios:
  - `git: Cmd+G opens the changes review of a dirty repo` still holds: the `dirty` fixture is on `main`, so the
    first Cmd+G opens the Local tab with the same rows and diff.
  - `git: Cmd+G with the project tree open replaces it` still holds: opening on the first tab still closes the
    project tree.
  - `git: ]f steps to the next changed file in the changes review` and `git: ]c steps to the next change in the
    changes review` still hold: the Local tab's file order and diff are unchanged.
  - `keymaps: Alt-g opens the changes review` still holds: the `billing` fixture is on `main`, so `<A-g>` opens
    the Local tab with the cursor on `invoice.go` and its diff.
  - `git: Changes panel mappings come from the shortcut file` still holds: `c` is assigned to
    `changes.toggle_commits` in `settings/keymap.json`.
  - `git: Changes panel entry points are actions` still holds: the new actions are added, the two named ones
    keep their titles and category.
  - `git: Changes panel lists the dirty fixture` and the other row scenarios still hold: the strip is a winbar,
    not a buffer line.
  - `keymaps: Changes review entry point` still holds: `<A-g>` still maps to `changes.review`.
  - `keymaps: Project tree and changes panel toggles` still holds: `<A-G>` still maps to `changes.toggle`, which
    opens, focuses and closes the panel as before, and opening one panel still closes the other.
  - `keymaps: Move selected lines down`, `keymaps: Move selected lines up`, `keymaps: Alt-j moves selected lines down` and `keymaps: Alt-k moves selected lines up` still hold: they name `c` only as buffer text; no global
    mapping changes.
  - `file-tree: Project tree c and p copy a file into another folder`, `file-tree: Project tree pasting a copy over an existing name asks for a new name`, `file-tree: Project tree c and p copy a folder recursively`,
    `file-tree: Project tree Visual c copies every selected row`, `file-tree: Project tree refuses operations on the root row` and `file-tree: Project tree Visual operations refuse the root row` still hold: the new `c` is
    buffer-local to `gleb-changes`; the project tree's `c` (`file_tree.copy`) is untouched.
- Out of scope:
  - The Comments tab, review threads and the statusline PR number (`pr-comments-view`).
  - A Branch-like tab on the default branch (e.g. unpushed commits; the user picked "Local only").
  - Staging, reverting or committing from the Branch tab; editing a committed side in the diff view.
  - Pushing, rebasing or fetching the base; the base is what `git-branch-base` resolved.

## Decision (user, 2026-10-19)

- Request: "Diff against base(for example pr diff, which is already comitted, in purple). And I somehow need to be
  able to see comitted diff."
- Colour: gruvbox purple (#d3869b).
- Panel: "I think cmd-g shortcut cycling through those two tabs and then closing would be perfect. No need to show
  both comitted and uncomitted in one tree. Also maybe comments tab aswell would be good." Cycle: Local →
  Branch → Comments → close (Comments comes with `pr-comments-view`).
- First Cmd+G: Local, or Branch when nothing is uncommitted — "consider that this should still fallback to local
  if branch is "master" branch, since we are not working in context of pr." On main/master: Local only.
- Branch tab: files by default — "I want per commit view on some shortcut with a tip how to switch to it as
  well." `c` toggles, hint row "Commits c · Next tab ⌘G" / "Files c · Next tab ⌘G".
- No PR: the Branch tab compares with `origin/main` and there is no Comments tab.
- "Also make sure there are [actions] for Threads and Branch Commits": Find Action entries open the Branch tab's
  commit view directly.

## Agent decisions

- The strip is the panel window's winbar, so the tree rows (and every row scenario) stay as they are; the
  approved mocks' blank row under the strip is dropped and the tree starts right under it.
- With the panel open, Cmd+G advances the tab wherever focus is (panel or diff window) and focuses the panel;
  `changes.toggle` (Cmd+Shift+G) keeps focusing or closing it.
- Diff labels are short (`4ccefde · main`, `e325463 · HEAD`) to fit the 26-column left pane, in today's
  `<hash> · <name>` form; the mock's `main · 1a2b3c4 (merge-base)` was cut off in a real capture.
- A commit's files are listed flat by name under the commit, as in the approved mock; "All changes" expands to
  the full tree.
- Commit subjects that do not fit end with `…`, like file names today.
- Committed diffs show no include checkboxes and no staging; moved blocks keep their aqua marks.
- `changes.show_branch` and `changes.show_branch_commits` on the default branch notify
  `No branch changes on main` at WARN and change nothing.
