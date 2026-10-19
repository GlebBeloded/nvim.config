# Spec Delta

## ADDED Requirements

### Requirement: Plugin update checks retain installed test dependencies
The private data prepared for a plugin update SHALL retain installed plugins, parsers, and Mason packages so the full check exercises the updated plugin with the same external test tools as the normal test environment.

#### Scenario: Plugin update data includes Mason tools
- **WHEN** the plugin update workflow prepares private test data from an installation containing `lazy`, `site`, and `mason` trees
- **THEN** all three trees are available to the update's test gate, including executables under `mason/bin`
