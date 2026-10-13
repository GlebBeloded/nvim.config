# Spec Delta

## ADDED Requirements

### Requirement: Active change scenarios participate in traceability
Traceability SHALL count scenarios added by active change deltas while excluding archived changes and
scenarios under `## REMOVED Requirements`.

#### Scenario: Trace counts scenarios an active change adds
- **WHEN** `make trace` runs where an active change (`openspec/changes/<id>/specs/<capability>/spec.md`) adds a scenario that a test names, and an archived change and a `## REMOVED Requirements` section list other scenarios
- **THEN** the added scenario is tested, the archived and removed ones are not scenarios, and nothing is orphan
