# Spec Delta

## Purpose

Define buffer-local fold summaries so every visible split describes the folded content it actually contains.

## ADDED Requirements

### Requirement: Buffer-local fold text
The editor SHALL select language-specific fold text and read folded lines from the buffer being rendered, regardless of which window is current.

#### Scenario: Split buffers use their own fold text
- **WHEN** Go and Lua buffers with closed folds are visible in separate splits
- **THEN** each split shows fold text generated from that split's filetype and folded lines
