# Spec Delta

## MODIFIED Requirements

### Requirement: Shared picker frame
By default, every shared picker SHALL draw a complete rounded border, keep only its title and query in the top border, omit a match counter, and place right-aligned muted hints below a joined rule. An opt-in hint-band mode SHALL instead reserve the final inner row for left-aligned hints and a right-aligned current/total counter, without a joined rule.

#### Scenario: Wide picker matches reference screenshot
- **WHEN** a default shared picker with sections, metadata and hints is shown in a window at least 72 columns wide
- **THEN** its frame, rows, joined hint rule and highlights match the approved wide reference screenshot

#### Scenario: Focused match remains above the hint row
- **WHEN** focus moves beyond the fourth result in a shared picker with at least six matches
- **THEN** the focused match remains visible in the reserved item area above the hint row

#### Scenario: Alternate picker views keep the border counter-free
- **WHEN** a default shared picker toggles from its main results into preview or info view
- **THEN** its complete border remains visible without a match counter

#### Scenario: Source-specific hint band shows hints and counter
- **WHEN** a shared picker starts in hint-band mode with applicable hints and populated matches
- **THEN** its final inner row shows left-aligned hints and a right-aligned current/total match counter without a joined rule

### Requirement: Picker rows
Picker rows SHALL place primary text first, optional secondary text after two spaces in a dimmer foreground, and optional category text right-aligned in a muted foreground. Metadata highlights SHALL not paint backgrounds. A section header SHALL use separate foreground highlights for its label and the rule that fills the remaining width.

#### Scenario: Rows expose primary secondary and category text
- **WHEN** the row renderer receives an item with primary, secondary and category text
- **THEN** it draws the fields in order with two spaces before secondary text, aligns the category right, and applies foreground-only metadata highlights

#### Scenario: Section header fills its row with a rule
- **WHEN** the row renderer receives a section header
- **THEN** it draws the heading followed by a rule through the remaining row width with distinct foreground highlights and no background patch
