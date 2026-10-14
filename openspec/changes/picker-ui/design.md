## Context

See proposal.md (Why). A throwaway mini.pick prototype was tested in a real tmux pty (25 headless checks). It showed that right-aligned extmark labels, a dimmed secondary text, inline toggle refresh and an in-place item reload all work through `source.show`, `MiniPick.set_picker_items` and the `mappings` option. mini.pick refreshes itself on `VimResized` (`MiniPick.refresh`), and `window.config` may be a callable that is evaluated again on each refresh.

## Goals / Non-Goals

**Goals:** one frame and one row renderer, shared by every list menu. The look follows the approved render in `find-action/design.md` ("Proposed H1 (approved)"). It adapts to small windows.

**Non-Goals:** tabbed "search everywhere" and new code-search menus.

## Decisions

1. **Base: mini.pick, with our own `source.show`.**
   - A snacks-like look is achievable through highlight groups and extmarks.
   - The prototype tried a separate input float above the list (S1, S2). The user preferred the single window with the query in the top border.
   - Alternatives are in the proposal table.
2. **Frame.**
   - The top border text is `<title> › <query>`, through mini.pick's prompt in the window title.
   - Hint row:
     - It is the last buffer line of the list area, under a `├─┤` rule. The rule is drawn as virtual lines on the border columns; where the border cannot be joined, it falls back to an inner `─` rule.
     - Hints are right-aligned in [PmenuExtra] style.
     - Matches never scroll under the hint row: the hint row is reserved, and the item area is the window height minus 2.
3. **Row renderer** `picker.rows.render(buf, items, width, opts)`.
   - Each item has `{ text, secondary?, category?, glyph?, dim?, section? }`.
   - `secondary` gets a group dimmer than `category`.
   - A glyph sits before the category: `●` [PmenuKind] when on, `○` [PmenuExtra] when off.
   - Breakpoints are constants at the top of the file (rule 4.3): `FULL_MIN = 72`, `COMPACT_MIN = 48`, `SHORT_LINES = 15`.
4. **Grep and references** use mini.extra pickers wrapped by the frame, so they get the same hint row (`Open ↩ · Split ⌃S · Vsplit ⌃V`). Their exact hint texts and renders are drawn in the design step.
5. **`vim.ui.select`.** A single override in `lua/gleb/picker/select.lua` replaces `lua/gleb/select/`. Code actions keep the cursor-anchored small float, since the select spec pins a width that fits its content, but they use the same frame and rows.

## Renders

The approved frame is "Proposed H1 (approved)" in `openspec/changes/find-action/design.md`. Live-grep, references and code-action renders (Current from `make render`, Proposed in the H1 frame) are added in the design step before implementation, so the preview and design gate can approve them.

## Risks / Trade-offs

- [mini.pick puts the prompt in the window title, and very long queries truncate] → the title is cut from the left, so the caret stays visible.
- [A joined `├┤` rule is not a native border feature] → the fallback inner rule is pinned by a screen test, so it cannot regress silently.
- [99's native picker extension looks different] → 99 search uses the shared `vim.ui.select`, where possible through its native extension.

## Migration Plan

1. Land `picker/` alongside telescope.
2. Switch `gr`, `<A-F>`, `ui.select` and 99.
3. Remove telescope and project.nvim's extension in the same change.

Rollback: revert the change, which restores the telescope spec and wiring.
