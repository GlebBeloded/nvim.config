---
description: Independent AI review of the change branch
---
# Review

First, load each of these skills before any other step: `superpowers:requesting-code-review`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$requesting-code-review. Report each skill as it loads. If one does not load, stop and
report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **review**. Input: the branch diff. Output: the JSON fields only. Do not: edit files or fix findings (fix does that), run make test or make check (the gate logs are `$ARTIFACTS_DIR/check-*.log`). Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Change id: $INPUTS.change. Diff: `git diff $(git merge-base HEAD $BASE_BRANCH)` plus untracked files.

One pass, exhaustive: for each requirement and scenario of the change's delta, check every unit that
implements it (every adapter, caller or plugin integration, not a sample; for a plugin, its native API
in the installed plugin source), and list all `[must-fix]` findings at once: each later pass costs a full
gate. Check each requirement across its entry points (keymap, button `<CR>`, command), data states (empty, populated)
and views/events (main, alternate views, move, resize), with one `make probe` per relevant cell. A `[must-fix]` in code an earlier pass already reviewed unchanged also says why that pass missed it.

Use `superpowers:requesting-code-review` as the checklist, acting as the reviewer yourself. Judge
the diff against the conventions in docs/architecture.md and openspec/specs plus the change's spec delta:
- consistency with the conventions (cite the rule number);
- scope creep beyond proposal.md: an edit to a file the proposal and tasks.md do not cover is `[must-fix]`,
  unless the gate needed it to go green (then say so in the finding and mark it `[minor]`); in scope, no
  finding: new test files for the change's scenarios, files `make fmt` changed only in whitespace, and
  `openspec/changes/<change>/`; if `$ARTIFACTS_DIR/fix-scope.md` exists, the last fix pass edited
  the planning files it lists (proposal.md, .openspec.yaml, spec deltas): a finding unless the edit only
  repairs a failed `openspec validate` or trial archive;
- test integrity: no deleted, skipped, xfailed or weakened tests, no loosened assertions, test
  names match scenario titles; new case names must not already exist under tests/;
- spec integrity: no scenario removed or weakened;
- reuse over custom code (an existing plugin or built-in would do);
- agent decisions: each line under tasks.md `## Agent decisions` is consistent with the spec, design.md and any `## Decision`; one that changes user-visible behaviour beyond them or contradicts them is `[must-fix]`;
- docs (rule 10): no doc restating code logic, no markdown outside the allowed locations, every
  docs/ file linked from README.md, no dangling relative links, no stale references.

Evidence bar: cite file:line for each finding; drop anything that rests on "might". Do not edit
files. Start each finding `[must-fix]` or `[minor]` (the judge lists `[minor]`
findings as notes, also on ship). Set `approve` to false only for findings that must be fixed before merge.
Before asking to restore or add wording to a requirement in the change's delta, check its text stays under 500 characters (OpenSpec strict); if it would not, ask to move the detail into a scenario instead.
