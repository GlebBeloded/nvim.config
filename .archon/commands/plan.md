---
description: Turn an OpenSpec change into a TDD task plan
---
# Plan

First, load each of these skills before any other step: `superpowers:writing-plans`. On Claude, load
each with the Skill tool. On Codex, invoke each by name: $superpowers:writing-plans. Report each
skill as it loads. If one does not load, stop and report the error naming it.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → verify → review → judge → ship.
Your step: **plan**. Input: the change folder. Output: tasks.md: small tasks, each naming its scenario test; no sub-skill header. Do not: write tests or code. Keep output brief.

Change: openspec/changes/$INPUTS.change/
User feedback from the approval gate (may be empty, it overrides the proposal): $INPUTS.feedback

Use the `superpowers:writing-plans` skill, but write the plan into the change's tasks.md (not a
separate plan file). Follow openspec/config.yaml `rules.tasks`: each task lists the scenario
titles it satisfies, and its first step is a failing mini.test case named exactly
"<capability>: <scenario title>" (docs/testing.md picks the layer). Keep tasks small, reuse
plugins and built-ins (docs/architecture.md, Conventions). Do not write code.
