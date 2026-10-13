# Proposal

## Why

Fresh loop attempts receive only the immediately previous pass, so fixes for recurring operational mistakes are scattered through old changes and disappear across runs. The loop needs a small durable memory that is read before work and updated only after a failed-attempt reason has been corrected.

Kind: bug

## What Changes

- Add a short, bounded `Loop lessons` section to `docs/workflow.md` containing one-line known flakes or pitfalls and their corrective action.
- Make the fix/explore and implement prompts read that section before starting work.
- Carry candidate lessons from an implementing attempt to the verdict/escalation path; append only lessons for earlier-attempt failures that a later attempt fixed, normalize and deduplicate them, and keep the section bounded.
- Add headless loop tests for prompt references and for append, deduplication, and size-limit behaviour.
- No plugin dependency is added, removed, or upgraded. No core keymap changes.

Out of scope: storing raw logs or full retrospectives in the lessons section, importing old run history automatically, changing Archon's `fresh_context` policy, and teaching feature-specific behaviour that belongs in capability specs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loop`: agents read durable operational lessons before fix/build work, and the build verdict/escalation path retains a corrected prior-attempt failure as one bounded, deduplicated lesson.

## Impact

Affected areas are `docs/workflow.md`, the fix/explore and implement commands, the `nvim-deliver` build-loop data flow, the verdict/escalation scripts, and `tests/unit/loop/`. The format is repository-local Markdown and introduces no external API or dependency.
