## Why

Kind: feature
Adopt: loop/diff-view-actions
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

## Decision (auditor, 2026-10-17, pre-implementation audit)

- `diff.apply` and `diff.toggle_include` do nothing (and notify) when the file is absent from HEAD, unborn, unmerged or binary. The toggle re-reads the index first and refuses with "Stage failed: overlaps other staged lines" instead of reverting staged edits outside the change. Staging and checkbox states always use `policy = default`. The patch's old side matches the index blob's own end-of-file newline; the new side takes the buffer's `'eol'` only when the change touches the last line; a CRLF unit case. The `index.lock` scenario uses `git rev-parse --git-path index.lock`.
- `highlight = "none"`, a policy that hides every change, and reverting the last change all keep the view open with no fold: `build()` stops treating zero fragments as "No changes" in those cases. Three scenarios cover them.
- `<Space>` stays the include key (the approved design); scenarios prove `<leader>` mappings still work inside the view and in another window of the same file. Mappings keep the per-view namespace and augroup, and `FocusGained` lives in `view.augroup`.
- Tasks update `test_run.lua` `more_results`, `test_layout.lua` (checkbox state and signature) and `ADAPTER_PLUGINS` keyed on `action.plugin`. Without an index the checkbox defaults to `☐`, so the approved render and plain-spec tests stay unchanged. Reuse `layout.change_at_line` instead of a second lookup.
- Split task 2 into 2a (revert, `do`/`dp`), 2b (`stage.lua` and the toggle with its failure case), 2c (checkbox states and drawing), and task 4 into 4a (`settings.lua` with its unit test), 4b (the nine radio actions), 4c (the `none`-mode layout). Moves get a per-side kind on rows; lookups use a line→row map built once (no per-line row scan) and a two-pointer pass for states. Screen masks come from `renders/*.ansi`, never from the implementation's own screenshots.

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

## Rejected run
Run on `loop/diff-view-actions` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] Unstaging a change that touches the last line gives the index the buffer's final newline, not HEAD's, so the line stays staged. The faulty line is lua/gleb/diff/view/init.lua:548-549: when `fragment.end2 == #view.right`, it sets `new_final_newline = right_final_newline` for both stage and unstage. The auditor Decision applies the buffer's 'eol' to the new side only when that side holds the buffer's lines. On unstage the new side holds HEAD's lines, and the "Diff view hunk staging" requirement says unstage returns the index to them.
  - Probe (`make probe`): a repo with d.txt "first\nsecond\nthird\n" committed; line 3 edited to THIRD; the buffer set to `noeol nofixeol`; `toggle_include` run twice on line 3. After the second toggle, `git diff --cached` still holds `-third` / `+third` with `\ No newline at end of file`, while the checkbox shows ☐. The index never returns to HEAD.
  - Fix: when `include` is false, take HEAD's final newline. source.lua:58 drops it, so record it from `left_result.stdout` (for example `head_final_newline` on the source and view). When the change touches the last line, also use it for the patch's new side.
  - Test: extend "Diff view stages a final line without a newline" (tests/integration/diff/test_actions.lua:214), or add a scenario: press `<Space>` twice, then expect `git diff --cached` empty and ☐.
  - Why pass 4 missed it: its finding looked only at the `and/or` fallthrough on the stage path. The same line already ignored HEAD's newline on u
- note: loop: No test cases matched
- note: loop: lua/gleb/diff/view/init.lua:472:77 [Warning] Cannot assign `gleb.diff.LineFragment` to parameter `gleb.diff.PatchChange`.
- note: loop: pinned scenarios with no delta and no Impact line (each needs a MODIFIED delta restated to the new behaviour, or one line in proposal.md `## Impact` naming it in backticks and why it still holds):
