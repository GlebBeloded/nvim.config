## Why

Kind: feature

Depends: git-branch-base

The user (2026-10-19) wants "Diff against base(for example pr diff, which is already comitted, in purple)".
In the editor today, a line committed on the branch looks exactly like a line `main` already had. Only
uncommitted lines get gitsigns bars, so while working on a PR branch there is no way to see which code the
PR itself changed. IntelliJ's review mode marks those lines in the gutter. The approved look
(`pr_colour_gruvbox` / `pr_gutter`) draws them as a purple bar next to the blue and green uncommitted ones.

## What Changes

- **New gutter layer** `lua/gleb/git/committed_signs/`:
  - `map.lua` (pure) diffs the merge-base text with the HEAD text (`vim.text.diff`, myers with the indent
    heuristic, as `git diff`) and maps those lines onto the live buffer through a second diff of HEAD against
    the buffer. Unsaved edits move the signs. A committed line that changed locally loses its purple sign, and
    gitsigns marks it.
  - `init.lua` attaches to normal file buffers and reads the two blobs with `git cat-file`. It places
    extmark signs in namespace `gleb_git_committed_signs` at priority 5, below gitsigns' 6, and re-maps on
    edits (150 ms debounce) and on `User GlebGitBaseChanged`.
- **Signs:** the same `┃` bar and delete glyph as gitsigns, from a new shared `lua/gleb/git/sign_text.lua`
  that `gitsigns.lua` now also reads. All committed signs use the new highlight `GitCommittedSign`, the
  gruvbox-material palette purple `#d3869b`.
- **Always on** wherever `gleb.git.base` gives a base. There is no toggle, action or key. On `main`,
  `master`, the default branch, a detached HEAD or outside a repository, nothing is drawn and no git runs.
- **Bounded work:**
  - only files that `git diff --name-status -M <merge-base> <head>` lists are read, a rename being compared
    with its old path;
  - binary files, files over 2 MiB and files over 20 000 lines are skipped;
  - re-mapping 10 000 lines takes about 1 ms.
- **Render case** `committed-signs` in `tests/render/cases.lua`, and a screen test against the approved
  render.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `git`: added "Committed signs", "Committed signs follow the buffer", "Committed signs limits" and
  "Committed signs screen".

## Impact

- Code:
  - New: `lua/gleb/git/committed_signs/init.lua`, `lua/gleb/git/committed_signs/map.lua`,
    `lua/gleb/git/sign_text.lua`.
  - Changed: `lua/gleb/git/init.lua` (requires `gleb.git.committed_signs` after `gleb.git.gitsigns`) and
    `lua/gleb/git/gitsigns.lua` (sign texts from `sign_text.lua`, same characters).
- Tests:
  - New: `tests/unit/git/test_committed_map.lua`, `tests/integration/git/test_committed_signs.lua`,
    `tests/screen/git/test_committed_signs_screen.lua` with its reference screenshot.
  - Changed: the `committed-signs` case in `tests/render/cases.lua`.
- Plugins: none added or removed. Alternatives checked for a second git layer:
  - gitsigns `change_base` replaces the local layer instead of adding one;
  - mini.diff has one reference per buffer, and the git spec forbids it next to gitsigns;
  - diffview has no gutter.
- Core keymaps: none.
- Unchanged scenarios:
  - `git: Added line shows bar sign` still holds: gitsigns' texts come from `sign_text.lua` with the same
    `┃` character.
  - `git: Added line has no competing hunk sign` still holds: that temp repo is on `main` with no `origin`,
    so it has no base and no committed sign. gitsigns stays the only hunk-sign plugin, and `mini.diff`
    stays absent.
  - `git: Added line sign matches reference screenshot` still holds: same temp repo with no base, so no
    other line gets a sign.
  - `git: Blame is off by default` still holds: the gitsigns options other than the sign texts are
    untouched.
  - `diff: A too big comparison falls back to xdiff` still holds: the committed layer calls `vim.text.diff`
    on its own, and the diff engine's fallback and options are untouched.
  - `diff: Diff view hunk staging` still holds: staging patches are built by `diff/stage.lua` as before. The
    committed layer stages nothing.
  - `git: Missing optional git plugins are tolerated` still holds: `gleb.git.committed_signs` requires no
    plugin, and `gitsigns.lua` keeps its `pcall` guard.
  - `file-tree: Project tree hides the git folder` still holds: the committed-sign layer does not change
    project-tree filtering.
  - `file-tree: Requirement: Project tree refresh and operation keys` still holds: the committed-sign
    refresh path is separate from project-tree refresh and mappings.
  - `file-tree: Requirement: Project tree refresh isolation` still holds: committed-sign state is scoped
    to file buffers and does not replace project-tree view state.
  - `file-tree: Ignored entries are hidden by default` still holds: the committed-sign layer does not
    change project-tree ignored-entry filtering.
  - `file-tree: Expanded ignored folder lists ignored children` still holds: the committed-sign layer
    does not change project-tree expansion or git-status requests.
  - `file-tree: Project tree refresh survives failed git status` still holds: project-tree refresh and its
    failure handling are unchanged.
  - `lsp: diagnostic signs use Nerd Font glyphs` still holds: the new git sign highlight and text do not
    change diagnostic sign configuration.
  - `statusline: refresh timer stops when idle` still holds: the committed-sign layer does not change the
    LSP progress refresh timer.
  - `statusline: refresh timer stops on exit` still holds: the committed-sign layer does not change the
    LSP progress timer's exit cleanup.
- Out of scope:
  - Purple in the diff view and the changes panel (`git-changes-tabs`).
  - Committed-hunk actions (preview, reset, stage).
  - Number-column or line highlights for committed lines.
  - A toggle.

## Decision (user, 2026-10-19)

- "Diff against base(for example pr diff, which is already comitted, in purple). And I somehow need to be able to see comitted diff."
- P1 colour: gruvbox purple (#d3869b; IntelliJ's review-mode marker is pink-magenta REVIEW_CHANGED_LINES_COLOR, gruvbox purple is the closest palette colour).
- P2 gutter: purple layer always on, on a branch with a base.
- R3.6 main/master: Local only.

## Agent decisions

- **Local wins by dropping.** A committed line that changed locally gets no purple extmark at all, so
  `signcolumn = "yes"` never depends on which sign wins a priority tie. Priority 5 is a second guard for the
  moments between a gitsigns update and a debounced re-map.
- **Same shapes as gitsigns.** Kinds follow gitsigns' semantics (add, change, changedelete, delete,
  topdelete). Only the colour tells the two layers apart, as in the approved mock.
- **Oids, not `HEAD`.** The blobs are read by oid, so a commit made while they are read cannot mix two
  revisions.
- **The render leaves out the later changes' chrome.** Proposed is the editor part of the approved mocks.
  Their left panel was the superseded two-roots option, and the `#482` statusline chip is
  `pr-comments-view`.
