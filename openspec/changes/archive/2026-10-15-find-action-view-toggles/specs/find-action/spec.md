# Find Action Spec Delta

## MODIFIED Requirements

### Requirement: Actions run in the opening context
Choosing a regular action SHALL close the palette and run it in the captured window, buffer, cursor, mode, and visual selection. Choosing a toggle SHALL change it in that context and keep the palette open on the same row. Soft Wrap SHALL toggle `wrap` and Spell Check SHALL toggle `spell` for the captured window. A visual-mode palette SHALL list only visual actions and preserve the selection.

#### Scenario: Regular action runs like its shortcut
- **WHEN** a listed action is chosen after the palette has taken focus
- **THEN** the palette closes and the action has the same observable effect as its shortcut in the captured context

#### Scenario: Toggle changes without closing the palette
- **WHEN** `<M-A>` opens Find Action and Enter is pressed on Soft Wrap or Spell Check
- **THEN** the corresponding `wrap` or `spell` option flips only in the captured window, its glyph refreshes, and the palette remains open with the same row selected

#### Scenario: Visual palette preserves the selection
- **WHEN** `<M-A>` opens the palette from visual mode
- **THEN** only visual-mode actions are listed and choosing one runs it with the captured selection restored
