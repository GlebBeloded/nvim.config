## MODIFIED Requirements

### Requirement: Action ordering and matching
With no query, the palette SHALL place up to 20 persisted recent action ids before curated actions. It SHALL record catalog actions run from the palette or a configured shortcut. Queries SHALL fuzzy-match titles, categories, and aliases. Multi-word queries SHALL also match category followed by title as one value; single-word matching SHALL remain unchanged. Section rows SHALL be display-only, and the first actionable match SHALL be current after results open or change.

#### Scenario: Empty query puts recent actions first
- **WHEN** catalog actions are run from a configured shortcut and from the palette, then the palette is reopened with no query
- **THEN** the persisted applicable actions appear before the curated action section in most-recently-used order

#### Scenario: Shortcut and palette use update recent actions
- **WHEN** one catalog action runs from a configured shortcut and another runs from the palette before reopening it
- **THEN** both actions appear in the recent section with the last-used action first

#### Scenario: Only executed shortcuts update recent actions
- **WHEN** configured mapping and plug shortcuts execute, and a colliding configured shortcut key is consumed as input by an open picker
- **THEN** only actions whose shortcut mappings executed are added to recent history

#### Scenario: Recent history keeps the last 20 actions
- **WHEN** more than 20 distinct actions are run and the history is loaded in a new session
- **THEN** only the 20 most recently used action ids remain in order

#### Scenario: Query matches all searchable fields
- **WHEN** a query fuzzy-matches an action title, category, or alias
- **THEN** that action appears in the matching results

#### Scenario: Multi-word query spans category and title
- **WHEN** an action has category `Project` and title `Open`
- **THEN** `project open` matches the action, `open project` does not match it through the combined field, and the existing single-word `project` and `open` matches are unchanged

#### Scenario: Selection skips section rows
- **WHEN** the palette opens or Show hidden or a query makes a section row the first match
- **THEN** the first actionable match is selected and Enter, `<M-}>`, and navigation all act from that row
