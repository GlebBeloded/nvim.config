## Why
User report (2026-10-15): action names and casing differ from the approved render. The render uses Title Case names that read on their own ("Open Differ", "Find in Files...", "Toggle File Tree") and two-level categories (`Git | Diff`, `View | Editor`, dim `|`). The palette shows sentence-case, context-free titles ("Live grep", "Open one", "Close all", "Move left", "Toggle") with one-word categories. Screenshots: `/tmp/find-action-match/render.png` (the approved render: match it) and `/tmp/find-action-match/impl.png` (the live palette today); copies in `evidence/` of this change. Read both images before planning and compare the live palette with render.png row by row (`make render` / a reference screenshot) before handing back.

Kind: bug
Depends: fix-find-action-colors

## Evidence
About 45 palette-visible titles:
- `lua/gleb/keymaps/actions.lua:69-256`:
  - Move left/down/up/right → Focus Left/Down/Up/Right Window
  - Back/Forward → Navigate Back/Forward
  - Increase/Decrease height/width → … Window Height/Width
  - Close → Close Buffer
  - Live grep → Find in Files...
  - Code actions → Show Code Actions...
  - Go to Declaration/Definition/Implementation
  - Hover → Show Hover Info
  - Find References; Rename Symbol...; Next/Previous Diagnostic
- `folding/actions.lua:17-20`: Open/Close all, Open/Close one → Expand All Folds, Collapse All Folds, Expand Fold, Collapse Fold
- `comments/actions.lua:15`: Toggle → Toggle Comment
- `file_tree/actions.lua:247,255`: Toggle File Tree, Toggle Git Status Tree
- `autocommands/actions.lua:7`: Close → Close Window
- `ai/actions.lua:9-31`: AI Search, AI Vibe, AI Edit Selection, Submit AI Prompt
- `surround/actions.lua:30-40`: Add/Delete/Change Surrounding…
- `git/actions.lua:63,72`: Confirm/Discard Commit Message
- `plugins/actions.lua:12`: Close Lazy
- `lsp/actions.lua:9`: Install Package

These names are a suggestion; follow the render's style. Categories are flat strings today (`category = "Git"`).

Root cause:
- `lua/gleb/keymaps/actions.lua:69-256`, `lua/gleb/folding/actions.lua:17-20`, and the other action files listed above define the sentence-case, context-dependent titles and flat categories in the catalog.
- `lua/gleb/find_action/rows.lua:72-77` copies each catalog title and category into a palette row unchanged.
- `lua/gleb/picker/rows.lua:97-118` renders and highlights the category as one span, so a hierarchy separator cannot be dimmed independently.
- `tests/screen/find-action/test_palette.lua:14-51` uses a hand-built catalog that already contains the approved labels, so its reference screenshots do not exercise the live catalog values shown in `evidence/impl.png`.

## What Changes
- Every palette-visible action title is Title Case and unambiguous without its category (IntelliJ style, as in render.png).
- Categories gain a second level where the render shows one (`Git | Diff`, `View | Editor`, `View | Tool Windows`, `Edit | Find`), drawn with a dim ` | ` separator.
- Action ids, shortcuts and the recent history file are unchanged.

## Impact
- Code: the action metadata in `lua/gleb/keymaps/actions.lua`, `lua/gleb/folding/actions.lua`, `lua/gleb/comments/actions.lua`, `lua/gleb/file_tree/actions.lua`, `lua/gleb/autocommands/actions.lua`, `lua/gleb/ai/actions.lua`, `lua/gleb/surround/actions.lua`, `lua/gleb/git/actions.lua`, `lua/gleb/plugins/actions.lua`, `lua/gleb/lsp/actions.lua`, `lua/gleb/testing/actions.lua`, `lua/gleb/alpha/actions.lua`, `lua/gleb/debugging/actions.lua`, `lua/gleb/copilot/actions.lua`, and `lua/gleb/cmp/actions.lua`; category rendering in `lua/gleb/picker/rows.lua`.
- Tests: real-catalog integration coverage, action-description expectations, Find Action screen coverage, and its reference screenshots.
- Dependencies: no plugin is added, removed, or upgraded.
- Core keymaps: unchanged; action ids, shortcut lhs values, and recent-history storage are unchanged.
- Architecture: none; module layout, load order, and plugin wiring stay unchanged (`lua/gleb/plugins/actions.lua` changes action metadata only).
- Out of scope: changing action behavior, responsive layout, picker ordering, matching, shortcut assignment, or history migration.
