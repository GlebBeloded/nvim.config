## Why

Kind: feature
Depends: diff-view

`diff-view` draws IntelliJ's chrome, but its `»` arrows and `☐` checkboxes do nothing yet. The user picked the aligned look for what those controls do in IntelliJ:
- `»` reverts one change;
- the checkbox includes one change in the commit.

The user also wanted move detection ("only if IDEA doesn't have it"; IntelliJ has none, so VS Code's was ported in `diff-engine-moves`), and IntelliJ's whitespace and highlight choices. Today, staging one hunk means differ's or diffview's own panels, and nothing shows moved code.

## What Changes

- **Revert (`»`).** `diff.apply` (`do` and `dp`, in either window) replaces the right buffer's lines of the change at the cursor with its `HEAD` lines.
  - This is IntelliJ's "Revert" for local changes.
  - It is one undo step, without saving, and the view re-compares at once.
- **Include checkbox = index.** Each change's checkbox shows its state in the index, comparing `HEAD`, the index (`git show :<path>`) and the right buffer:
  - `☑` when the index holds the change's right lines;
  - `☐` when it holds its `HEAD` lines;
  - `◪` otherwise.
- **`diff.toggle_include` (`<Space>`)** stages a `☐`/`◪` change and unstages a `☑` one.
  - It builds the new index text for that change only, diffs it against the current index text with `vim.text.diff`, and pipes the patch to `git apply --cached --whitespace=nowarn -` (argument list, patch on stdin, repository root as cwd).
  - Other staged changes stay.
  - Failures notify `Stage failed: <stderr>` or `Unstage failed: <stderr>` at ERROR, as the existing staging does.
- **Moved blocks.** The view asks the engine for moves.
  - Both ends of a move are tinted `DiffViewMoved` (aqua) instead of red and green.
  - The strip on each end's first row reads `→<line>` on the original end and `←<line>` on the moved end.
  - `diff.jump_move` (`gm`) on a moved row focuses the other window, on the other end's first line.
- **Whitespace policy and highlight mode,** as IntelliJ radio actions in Find Action. They are available while a diff view is current, and unbound.
  - Whitespace: "Do Not Ignore", "Trim Whitespaces", "Ignore Whitespaces", "Ignore Whitespaces and Empty Lines".
  - Highlight: "Highlight Words" (default), "Highlight Split Changes", "Highlight Symbols", "Highlight Lines", "Do Not Highlight".
  - A choice re-compares every open view and persists in `stdpath("state")/diff.json`.
- **Keys** in `settings/keymap.json`, view-scoped through the `gleb-diff` adapter:
  - `diff.apply` `do`, `dp`;
  - `diff.toggle_include` `<Space>`;
  - `diff.jump_move` `gm`.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `diff`: Added "Diff view revert", "Diff view include checkbox", "Diff view hunk staging", "Diff view moved blocks", "Diff view whitespace policy", "Diff view highlight mode" and "Diff view action colours".

## Impact

- Code:
  - New: `lua/gleb/diff/stage.lua` (git calls), `lua/gleb/diff/patch.lua` (pure: checkbox state, new index text, patch text) and `lua/gleb/diff/settings.lua` (persisted policy and mode).
  - Changed: `lua/gleb/diff/actions.lua`, `view/{init,layout,render,highlights}.lua` (moves, checkbox states, settings) and `settings/keymap.json` (`diff.apply`, `diff.toggle_include`, `diff.jump_move`).
- Tests:
  - unit: `patch.lua` (states and index texts) and `settings.lua`;
  - integration: revert, staging on `diffgo` and `dirty`, moves on `diffgo`'s `ids.go`, and the policy and mode actions;
  - screen: Proposed E1 and E2.
- Plugins: none added or removed.
- Core keymaps: none. The new keys are buffer-local to the two diff windows.
- Unchanged scenarios:
  - `diff: Diff view matches the approved render` still holds: the `diffgo` file has no staged change and no move, so every checkbox stays `☐` and every tint stays.
  - `diff: Diff view gutter shows both line numbers` still holds: unstaged changes keep `☐`.
  - `git: s stages entry from file panel` still holds: diffview's staging is untouched.
  - `file-tree: Space reports a staging failure` still holds: the neo-tree staging action is untouched; only its error wording is reused.
- Out of scope:
  - Staging a file absent from `HEAD` (no checkbox is drawn) and staging from Visual mode.
  - Appending (IntelliJ's Ctrl-click), and differences inside a moved block.
  - Cross-file moves.
  - The `FORMATTING` and language-specific ignore policies.
  - Committing (`git-changes-tree`).

## Decision (user, 2026-10-17)

- Move detection: "Let's get Move detection (but only if IDEA doesn't have it)". IntelliJ has none (YouTrack IJPL-101150, open since 2015), so the user picked "Port VS Code's move detection".
- Panes: picked "Aligned, IntelliJ chrome" (numbers in the middle, » apply, checkbox per change, ╱ padding, wavy folds).
- General: "I'm used to Idea", "I like IDEA IDE diff more".

## Agent decisions

- **Apply key `do` and `dp`.**
  - IntelliJ's `Ctrl+Shift+Right` would be a new terminal chord through Alacritty and zellij, which is a core-shortcut change (rule 3.8) with untested encoding.
  - Vim's own diff keys already mean exactly this: in the editable right window you obtain (`do`) the `HEAD` text, and from the read-only left window you put (`dp`) it.
  - Since only left → right is possible, both lhs run the same action in both windows. Neither clashes in `gleb-diff`; `d` stays an operator, because `o` and `p` are not motions.
- **`gm` for jumping between the ends of a move.** Native `gm` (half the screen width) is rarely used, and it is shadowed only while the view is open.
- **Staging is a patch of the index, not of `HEAD`.** The patch is the diff between the current index text and the new one, so it always applies with full context, keeps other staged hunks, and never touches the working tree. The right side is the buffer, so unsaved edits are staged as shown, like IntelliJ's partial commit of the document.
- **`◪` for a change that the index holds neither way.** `<Space>` on it stages the right lines, like a click on IntelliJ's mixed checkbox.
- **Settings are radio actions without keys.** IntelliJ has none for them either. They persist globally, not per file.
- **Move markers** `→n` / `←n` sit in the 5-cell strip, so no column is added. Aqua is the palette's free accent here.
