---
description: Independent AI review of the change branch
---
# Review

First, load each of these skills before any other step: `superpowers:requesting-code-review`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$requesting-code-review. Report each skill as it loads. If one does not load, stop and
report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **review**. Input: the branch diff. Output: the JSON fields only. Do not: edit files or fix findings (fix does that). Keep output brief.

Change id: $INPUTS.change. Diff: `git diff $(git merge-base HEAD $BASE_BRANCH)` plus untracked files.

Use `superpowers:requesting-code-review` as the checklist, acting as the reviewer yourself. Judge
the diff against the conventions in docs/architecture.md and openspec/specs plus the change's spec delta:
- consistency with the conventions (cite the rule number);
- scope creep beyond proposal.md;
- test integrity: no deleted, skipped, xfailed or weakened tests, no loosened assertions, test
  names match scenario titles;
- spec integrity: no scenario removed or weakened;
- reuse over custom code (an existing plugin or built-in would do);
- docs (rule 10): no doc restating code logic, no markdown outside the allowed locations, every
  docs/ file linked from README.md, no dangling relative links, no stale references.

Evidence bar: cite file:line for each finding; drop anything that rests on "might". Do not edit
files. Set `approve` to false only for findings that must be fixed before merge.
