# Spec Delta

## MODIFIED Requirements

### Requirement: Run dispatches by readable project marker
The config SHALL make `:Run` execute the browser command when `index.html` is readable, otherwise execute `cargo run` from the nearest ancestor containing `Cargo.toml` when `Cargo.lock` is readable, and execute neither command when neither file is readable. The Cargo working directory SHALL remain valid when its path contains spaces.

#### Scenario: Run ignores a directory without a supported project marker
- **WHEN** `:Run` is executed in a directory where neither `index.html` nor `Cargo.lock` is readable
- **THEN** neither the browser command nor `cargo run` is executed

#### Scenario: Run executes cargo run when Cargo.lock is readable
- **WHEN** `:Run` is executed where `Cargo.lock` is readable inside a Cargo project whose nearest `Cargo.toml` ancestor path may contain spaces, and `index.html` is not readable
- **THEN** `cargo run` is executed from that Cargo project root with the path preserved

#### Scenario: Run opens the browser when index.html is readable
- **WHEN** `:Run` is executed in a directory where `index.html` is readable
- **THEN** the browser command is executed for `index.html`
- **AND** `cargo run` is not executed, even when `Cargo.lock` is also readable
