---
description: Complete the artifacts of a queued change
---
# Complete the queued change

First, load each of these skills before any other step: `openspec-continue-change`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $openspec-continue-change. Report each skill as it loads. If one does not
load, stop and report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **spec** (queued change). Input: the queued proposal. Output: the completed change folder and the JSON fields. Do not: write tests, code or tasks.md. Keep output brief.

Change: openspec/changes/$INPUTS.change/

The change is a queue item (for example a finding from a review) and may
only have proposal.md. Read it, find the root cause if it is a bug (systematic-debugging,
no code changes), then complete the missing artifacts with the `openspec-continue-change` skill
until specs, design (when there is visible UI: Current + Proposed renders) and tasks exist,
following openspec/config.yaml rules. Do not implement. Set `visible_ui` and `architecture` as in
a fix proposal (screen output changes / module layout, load order or plugin wiring changes).
