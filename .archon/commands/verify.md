---
description: Verify implementation against the change artifacts (/opsx:verify)
---
# Verify

First, load each of these skills before any other step: `openspec-verify-change`. On Claude, load
each with the Skill tool. On Codex, invoke each by name: $openspec-verify-change. Report each skill
as it loads. If one does not load, stop and report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **verify**. Input: the change and the branch diff. Output: the JSON fields only. Do not: edit files or fix findings (fix does that). Keep output brief.

Change id: $INPUTS.change

Run the `openspec-verify-change` skill for this change, non-interactively. Also run `make trace
VERBOSE=1` and check that every scenario the change adds or modifies is `tested`.
Do not edit files. Set `critical` to the number of CRITICAL findings (an untested scenario counts as
CRITICAL) and `findings` to the findings list with file:line evidence.
