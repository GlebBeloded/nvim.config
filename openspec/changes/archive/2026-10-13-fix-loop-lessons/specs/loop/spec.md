# Spec Delta

## ADDED Requirements

### Requirement: Agents start with durable loop lessons
The fix workflow's exploration prompt and every implementation pass SHALL read the curated `Loop lessons` section in `docs/workflow.md` after loading required skills and before investigating or changing the project.

#### Scenario: Fix and implement prompts read loop lessons
- **WHEN** the fix/explore and implement command sources are read in a headless child Neovim
- **THEN** both direct the agent to read the `Loop lessons` section of `docs/workflow.md` before starting their task

### Requirement: Corrected attempt failures become bounded lessons
The build verdict/escalation path SHALL append a supplied one-line lesson only for a failure from an earlier attempt that a later attempt reports fixed. It SHALL normalize whitespace, compare lessons case-insensitively, retain only one copy, and keep at most the 10 newest lesson lines without changing other workflow documentation.

#### Scenario: Passing retry records its corrected failure
- **WHEN** a later build attempt passes after an earlier failed attempt and supplies the one-line lesson `Under host load, scale startup budgets before diagnosing a regression`
- **THEN** the `Loop lessons` section contains that lesson exactly once

#### Scenario: Exhausted run retains a corrected earlier failure
- **WHEN** the build loop exhausts its final attempt but supplies a one-line lesson for a different earlier-attempt failure that the later attempt fixed
- **THEN** the escalation path records that lesson in the `Loop lessons` section before reporting the exhausted run

#### Scenario: Repeated lessons stay deduplicated and bounded
- **WHEN** the verdict/escalation path is invoked in a throwaway checkout with a lesson that differs from an existing lesson only by case or repeated whitespace, followed by enough distinct fixed lessons to exceed the limit
- **THEN** the equivalent lesson occurs once, the section contains the 10 newest lesson lines, and text outside the section is unchanged

#### Scenario: Unfixed failures do not become lessons
- **WHEN** an attempt fails and no later attempt supplies a lesson saying that failure was fixed
- **THEN** the verdict/escalation path does not add a lesson for that failure
