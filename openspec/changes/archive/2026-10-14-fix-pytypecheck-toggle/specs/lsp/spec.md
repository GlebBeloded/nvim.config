# Spec Delta

## ADDED Requirements

### Requirement: Python type-check mode toggle
The Python type-check commands SHALL change the configured type-check mode without reloading buffers and SHALL restore Python language-server service to every loaded Python buffer.

#### Scenario: Type-check toggle reattaches every Python buffer without reloading
- **WHEN** `:PyTypeCheckOn` or `:PyTypeCheckOff` is executed with two loaded Python buffers and the current buffer has unsaved changes
- **THEN** the command raises no error and basedpyright attaches to both Python buffers with the selected type-check mode
