# folding Specification

## Purpose
Define buffer-local fold summaries so every visible split describes the folded content it actually contains.

## Requirements

### Requirement: Buffer-local fold text
The editor SHALL select language-specific fold text and read folded lines from the buffer being rendered, regardless of which window is current.

#### Scenario: Split buffers use their own fold text
- **WHEN** Go and Lua buffers with closed folds are visible in separate splits
- **THEN** each split shows fold text generated from that split's filetype and folded lines

### Requirement: Fold shortcut actions
Folding SHALL expose open-one, close-one, open-all, and close-all actions without lhs values and SHALL obtain their global mappings only from `settings/keymap.json`.

#### Scenario: Fold keys invoke registered actions
- **WHEN** a buffer with closed folds is focused after `VeryLazy` and each configured fold lhs is pressed
- **THEN** the corresponding one-fold or all-fold action changes fold state
