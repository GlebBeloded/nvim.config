## ADDED Requirements

### Requirement: Code action picker fits the editor
The code-action picker SHALL set its content width to the greater display width of its formatted items and prompt, plus two columns of padding, capped at `vim.o.columns - 4`.

#### Scenario: Code action popup fits editor width
- **WHEN** code-action popup options are calculated in an 80-column editor for a prompt and formatted items that exercise both short and longer-than-screen content
- **THEN** short content uses its measured display width plus two columns and long content is capped at 76 columns
