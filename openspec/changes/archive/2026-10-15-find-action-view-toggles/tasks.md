## 1. Add window-local editor toggles to Find Action
Scenarios: `find-action: Toggle changes without closing the palette`
- [x] 1.1 Extend `tests/integration/find-action/test_run.lua` so `<M-A>` opens the real populated picker, Soft Wrap and Spell Check start from two distinct window-local states, and `<CR>` on each action must flip only its captured window option, refresh its glyph, keep the picker open, and preserve the selected row; run `make test FILE=tests/integration/find-action/test_run.lua CASE="Toggle changes without closing the palette"` and see it fail
- [x] 1.2 Add typed actions `view.soft_wrap` and `view.spell_check` in `lua/gleb/view/actions.lua`, wire that module into the catalog in `init.lua`, and update the existing row and wide-screen tests to consume these real actions instead of hand-built toggle stand-ins
- [x] 1.3 Run `make test FILE=tests/integration/find-action/test_run.lua CASE="Toggle changes without closing the palette"`, `make test FILE=tests/unit/find-action/test_rows.lua CASE="Toggle rows show state glyphs"`, and `make test FILE=tests/screen/find-action/test_palette.lua CASE="Wide palette matches reference screenshots"`; see all pass, then compare the screen reference row by row with `openspec/changes/find-action-view-toggles/evidence/render.png`

## Agent decisions
- Use action ids `view.soft_wrap` and `view.spell_check` in a dedicated `gleb.view.actions` module, matching the existing approved screen fixtures and the repository's feature-module convention.
