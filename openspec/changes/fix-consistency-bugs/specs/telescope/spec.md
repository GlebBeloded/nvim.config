## Purpose

Configures Telescope's prompt-local behavior and navigation mappings.

## ADDED Requirements

### Requirement: Telescope prompt navigation
The config SHALL map `<C-j>` to move to the next result and `<C-k>` to move to the previous result in Telescope insert mode.

#### Scenario: Telescope prompt maps move selection
- **WHEN** Telescope receives the configured insert-mode mappings
- **THEN** `<C-j>` is `actions.move_selection_next` and `<C-k>` is `actions.move_selection_previous`
