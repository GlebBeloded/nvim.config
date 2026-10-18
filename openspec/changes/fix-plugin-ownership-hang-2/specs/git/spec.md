# Spec Delta

## MODIFIED Requirements

### Requirement: Differ viewer
The config SHALL set up differ.nvim with split (side-by-side) layout, 3 lines of context, word-granularity deep diff, and a file panel on the left, 35 columns wide, listing files as a tree. A blocked `:Differ` open SHALL fail its test within 10 seconds with recorded child state instead of blocking the worker.

#### Scenario: Differ opens panel on the left
- **WHEN** `:Differ` is executed in a repository with working-tree changes
- **THEN** a new panel window is the leftmost window of the current tab with width 35 listing the changed files as a tree; if opening blocks, the test fails within 10 seconds with recorded child state
