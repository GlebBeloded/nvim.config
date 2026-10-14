## Purpose

Provides the `:Run` command and dispatches it according to project markers in the working directory.

## ADDED Requirements

### Requirement: Run dispatches by readable project marker
The config SHALL make `:Run` execute the browser command when `index.html` is readable, otherwise execute `cargo run` from the git root when `Cargo.lock` is readable, and execute neither command when neither file is readable.

#### Scenario: Run ignores a directory without a supported project marker
- **WHEN** `:Run` is executed in a directory where neither `index.html` nor `Cargo.lock` is readable
- **THEN** neither the browser command nor `cargo run` is executed
