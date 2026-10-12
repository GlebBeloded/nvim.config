---
description: Independent AI review of the change branch
---
# Review

Change id: $INPUTS.change. Diff: `git diff $(git merge-base HEAD $BASE_BRANCH)` plus untracked files.

Use `superpowers:requesting-code-review` as the checklist, acting as the reviewer yourself. Judge
the diff against docs/architecture/conventions.md and openspec/specs plus the change's spec delta:
- consistency with the conventions (cite the rule number);
- scope creep beyond proposal.md;
- test integrity: no deleted, skipped, xfailed or weakened tests, no loosened assertions, test
  names match scenario titles;
- spec integrity: no scenario removed or weakened;
- reuse over custom code (an existing plugin or built-in would do).

Evidence bar: cite file:line for each finding; drop anything that rests on "might". Do not edit
files. Set `approve` to false only for findings that must be fixed before merge.
