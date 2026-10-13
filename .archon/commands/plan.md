---
description: Turn an OpenSpec change into a TDD task plan
---
# Plan

First, load each of these skills with the Skill tool, before any other step:
`superpowers:writing-plans`. If one does not load, stop and report the error naming it.

Change: openspec/changes/$INPUTS.change/
User feedback from the approval gate (may be empty, it overrides the proposal): $INPUTS.feedback

Use the `superpowers:writing-plans` skill, but write the plan into the change's tasks.md (not a
separate plan file). Follow openspec/config.yaml `rules.tasks`: each task lists the scenario
titles it satisfies, and its first step is a failing mini.test case named exactly
"<capability>: <scenario title>" (docs/testing.md picks the layer). Keep tasks small, reuse
plugins and built-ins (docs/architecture.md, Conventions). Do not write code.
