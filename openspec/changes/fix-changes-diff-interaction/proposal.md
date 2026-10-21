## Why

Kind: bug

The user (2026-10-21) about the diffs the Changes panel shows: Branch and commit diffs are drawn in purple instead of
the Local tab's green/blue/red, the cursor does not start on the first change, and the user cannot work in the diff
panes (move in, scroll with hjkl, edit). `docs/architecture.md` (Key decisions, diff) says the right pane is the real
file buffer; git-changes-tabs made Branch diffs a nameless read-only copy of `HEAD` instead, in a purple layer.

## Evidence

Reproduced read-only on a fresh `billing-branch` copy (`feat/tax`, PR #482 from the fake `gh`), full config.

**Purple.** `make render CASE=changes-branch COLUMNS=100 LINES=30` (design.md, "Current — Branch diff in purple"):
every changed row of the Branch diff has `bg` `#544045` (`DiffViewCommitted`) and changed words `#7d5761`
(`DiffViewCommittedWord`); the capture holds no `DiffViewChange`/`DiffViewAdd` colour. Cause:
`lua/gleb/git/changes/git.lua:221` sets `committed = true` on every Branch and commit spec, and
`lua/gleb/diff/view/render.lua:32-37` (`row_suffix`), `:48`, `:80` (arrow) and `:209` (word) swap every kind group
for the `Committed` ones defined in `lua/gleb/diff/view/highlights.lua:23-27`.

**Cursor.** `make probe` (scratch `diffint/probe_interact.lua`) after `changes.review`; first change from
`view.fragments[1]`:

```text
local after review: tab=local current=panel right_cursor={ 1, 0 } left_cursor={ 1, 0 } first_frag_start2=11
branch after review: tab=branch current=panel right_cursor={ 1, 0 } left_cursor={ 1, 0 } first_frag_start2=9
```

Line 1 is inside the closed `~~ 4 unchanged lines ~~` fold. Cause: `lua/gleb/diff/view/init.lua:486-498` (`show`, the
panel's path) never places the cursor; only `open` (`:475-479`, `diff.open_file`) does. `]f`
(`git/changes/view.lua:520-521`) focuses the new right window after the same `show`. The commit view (same `show`) lands on
line 1 while its first change is line 9.

**Interaction.** A host script drove a full-config child with typed keys (`child.type_keys`, scratch
`diffint/host_interact.lua`), panel focused after `changes.review`:

```text
local <C-l>: current=left right=1/top1 left=1/top1 rbuf="invoice.go" modifiable=true modified=false
local <C-l><C-l>: current=right ...   local jj: right=8 left=8   local x: modified=true
branch review: current=panel right=1/top1 left=1/top1 rbuf="" modifiable=false
branch <C-l><C-l>: current=right   branch jj: right=6 left=6   branch G: right=37/top17 left=28/top17
branch x: E21: Cannot make changes, 'modifiable' is off
```

and `make probe` on the Branch right pane: `buftype="nofile" modifiable=false ft="" lsp=0 committed=true
actionable=false`. So:

- Branch and commit diffs cannot be edited: `git/changes/git.lua:184-243` (`load_branch_diff`) reads
  `git show HEAD:<path>` into lines and passes no `right_buf`, so `diff/view/init.lua:267` builds
  `readonly_buffer` (`:81-89`: `nofile`, `modifiable` off, no name, no filetype: no syntax, no LSP, nothing to `:w`).
- The first `<C-l>` (`window.move_right`) from the panel lands in the left pane, the read-only `HEAD`/merge-base
  copy (`diff/view/windows.lua:111-125`), where every edit fails; the cursor sits on line 1 of a fold in both
  panes.
- Motion itself works headless (hjkl, `<C-d>`, `G`, `gg`, `]c` move both panes together); the Local right pane is
  the real buffer and accepts edits. No focus guard or autocmd pulls focus back
  (`git/changes/view.lua:631` listens to `CursorMoved` on the panel buffer only). I don't know of another cause
  in the real terminal (e2e not run on the host); task 1 adds the failing tests that pin the three issues above.

## What Changes

- **One colour scheme for every diff.** Branch file diffs and commit diffs use the Local tab's groups
  (`DiffViewAdd`, `DiffViewChange`, `DiffViewDelete`, `DiffViewWord`, gutters, arrows, moved blocks). The
  `DiffViewCommitted*` groups go away. The purple stays where it marks committed work outside the diff: the
  Branch tab's pill, header and file names, and the committed gutter signs in normal buffers (`git-committed-signs`).
- **Cursor on the first change.** Every `show` (Local, Branch and commit diffs, `]f`) puts the right window's cursor
  on the first line of the first change, as `]c` would, the left on its transferred line; focus stays where it
  was (the panel), as today.
- **Branch diffs edit the working file.** A Branch file row compares `<merge-base>:<orig or path>` with the
  working-tree file, the right pane being the file's own buffer, loaded as the Local tab loads it (LSP, `:w`,
  live re-diff; deleted and binary files stay read-only lines). Uncommitted edits show too, in the same colours.
  The right winbar reads `Your version`. No include checkboxes, staging or revert (the left side is not `HEAD`).
- **Commit diffs stay history.** A commit's file diff (`<commit>^` → `<commit>`) stays read-only on both sides but
  is navigable like any diff, and its right side gets the file's Tree-sitter syntax like the left.
- **Jump to Source.** New `diff.jump_to_source` (`Jump to Source`, `Git | Diff`, `gf` in diff windows) closes the
  view and edits its working-tree file in the editor window, cursor on the line under the diff cursor (from the
  left side, its transferred line). For a commit diff it is the way into the editor.
- Moving between panel and panes stays on the existing window keys (`<C-h>`/`<C-l>`, `<C-w>h`/`<C-w>l`); the
  panel's own keys are unchanged.

## Capabilities

### New Capabilities

- none

### Modified Capabilities

- `diff`:
  - Modified (copied whole): "Diff view committed layer" (kind colours, editable `right_buf`, syntax on a
    read-only right side; "Diff view draws a committed spec in purple" keeps its title and now pins that no purple
    is drawn), "Diff view embedding" (cursor on the first change).
  - Added: "Diff view jump to source".
- `git`:
  - Modified (copied whole): "Branch tab diffs" (merge-base → working-tree buffer), "Branch tab files" and "Branch tab
    commit view" (their render scenarios name this change's Proposed renders for the diff columns).
  - Added: "Changes diff interaction" (cursor, entering the panes, synchronized motion, editing, read-only commits).

## Impact

- Code: `lua/gleb/diff/view/{init,render,highlights,windows}.lua` (cursor in `show`, committed layer, right-side
  syntax), `lua/gleb/diff/actions.lua` and `settings/keymap.json` (`diff.jump_to_source` on `gf`),
  `lua/gleb/git/changes/{git,view}.lua` (Branch spec with the working-tree buffer, loaded-buffer bookkeeping for
  Branch rows).
- Tests: `tests/integration/diff/test_committed.lua`, `tests/integration/diff/test_view.lua`,
  `tests/integration/diff/test_view_keys.lua`, `tests/integration/git/test_changes_tabs.lua`, new
  `tests/integration/git/test_changes_diff_interaction.lua`; screen `tests/screen/git/test_changes_tabs.lua` (Branch
  files and commits masks).
- Plugins: none added, removed or upgraded.
- Core keymaps: none. New view-local `gf` in diff windows (`diff.jump_to_source`); `gf` stays native in every other
  window and is replayed outside the view like the other diff keys.
- Unchanged scenarios:
  - `git: Branch tab ignores staging keys` still holds: Branch diffs stay not actionable and the panel's staging
    actions still do nothing on the Branch tab.
  - `git: Changes panel skips an unchanged selection` still holds: Branch rows keep their `branch:` diff key, so a
    refresh after `:w` keeps the shown view.
  - `diff: Diff view opens on the current file` still holds: `open` already places the cursor on the first change.
  - `diff: Diff view shows in a given window without focus` still holds: placing the cursor in `show` uses the
    window handles and keeps the current window.
  - `diff: Diff view editing` scenarios still hold: the left buffer stays read-only and edits of a given right buffer
    still re-compare.
  - `git: Committed signs` scenarios still hold: the committed sign groups of `git-committed-signs` are separate
    from the diff view's groups and keep purple.
  - `git: Changes tab colours` still holds: the panel's purple groups are unchanged.
  - `git: Changes panel ]f keeps diff focus` still holds: focus still moves to the new `right_win`, now on its first
    change.
- Out of scope:
  - The Comments tab: its rows preview the file at the thread's line (no diff view), which already places the
    cursor.
  - The Branch tab's file list and stats (still merge-base → HEAD); a file changed only locally stays on the Local tab.
  - Revert or stage hunks against the merge-base; editing a commit's history.
  - A panel key that focuses the diff directly (a new keymap would need the user).
  - Centring on open: `]c` does not centre today, and the first change is placed the way `]c` places it.

## Decision (user, 2026-10-21)

- "diff shown in purlple in commited(should be same green/red as for normal diff). Cursor should be at first diff hunk. Also, it seems that the diff view is not interactive. I can't put my cursor there scroll with hjkl and edit files. I should be able too."
- Lead decision (2026-10-21): the Branch tab's diff is merge-base → working-tree file, so the user can edit files
  there (uncommitted edits then show too, coloured normally); single-commit diffs stay read-only but navigable, with
  a key to open the file in the editor (IntelliJ: the current-version side is editable, Jump to Source opens it).

## Agent decisions

- The right winbar of a Branch file diff reads `Your version`, as the Local tab's, since that side is now the
  working tree.
- `diff.jump_to_source` takes `gf`, diffview.nvim's key for the same action in this config (`diffview.goto_file_edit`);
  IntelliJ's F4 is not used in this terminal setup.
- The `committed` spec field stays: it now means "history comparison" (not actionable, no checkboxes), no colour.
- "Diff view draws a committed spec in purple" keeps its title (strict validation refuses a dropped scenario in a
  MODIFIED requirement); its body now asserts that no `DiffViewCommitted*` group is drawn.
