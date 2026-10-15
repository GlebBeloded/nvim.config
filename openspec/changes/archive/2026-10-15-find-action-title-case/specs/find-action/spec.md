## MODIFIED Requirements

### Requirement: Action rows
Each catalog action row SHALL show a standalone Title Case title, two spaces before its first shortcut, and a right-aligned category, with no icon column. Approved two-level categories SHALL use `Parent | Child`, with the separator dimmer than both names. Equivalent Alt/Meta and control-key spellings SHALL share a physical label; unknown shortcuts SHALL use canonical Vim notation. Toggles SHALL show green `●` when on or grey `○` when off before the category, without ON/OFF text.

#### Scenario: Catalog rows use standalone Title Case labels
- **WHEN** `<M-A>` opens Find Action with the real populated action catalog
- **THEN** every palette-visible action has its approved standalone Title Case title and approved flat or two-level category while its action id and shortcuts remain unchanged

#### Scenario: Rows show action metadata
- **WHEN** an action with multiple shortcuts and a known physical label is listed
- **THEN** its row shows the title, two spaces, only the first shortcut's physical label, and the right-aligned category without an icon

#### Scenario: Rows fall back to Vim notation
- **WHEN** an action's first shortcut has no physical label
- **THEN** its row shows that shortcut in canonical Vim notation two spaces after the title

#### Scenario: Toggle rows show state glyphs
- **WHEN** available toggle actions in on and off states are listed
- **THEN** their rows show green `●` and grey `○` state glyphs respectively and no ON/OFF text

#### Scenario: Rows normalize shortcut spellings
- **WHEN** listed actions use equivalent Alt/Meta or control-key spellings such as `<A-F>`, `<C-h>`, `<M-H>`, or `<C-S>`
- **THEN** every known shortcut shows its corresponding physical label instead of raw Vim notation
