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

## What Changes
- Every palette-visible action title is Title Case and unambiguous without its category (IntelliJ style, as in render.png).
- Categories gain a second level where the render shows one (`Git | Diff`, `View | Editor`, `View | Tool Windows`, `Edit | Find`), drawn with a dim ` | ` separator.
- Action ids, shortcuts and the recent history file are unchanged.

## Impact
- Code: the `actions.lua` files above, `lua/gleb/find_action/rows.lua` (separator).
- Tests: cases asserting old titles, and screen references.
