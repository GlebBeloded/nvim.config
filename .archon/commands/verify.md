---
description: Verify implementation against the change artifacts (/opsx:verify)
---
# Verify

First, load each of these skills with the Skill tool, before any other step:
`openspec-verify-change`. If one does not load, stop and report the error naming it.

Change id: $INPUTS.change

Run the `openspec-verify-change` skill for this change, non-interactively. Also run `make trace
VERBOSE=1` and check that every scenario the change adds or modifies is `tested`.
Do not edit files. Set `critical` to the number of CRITICAL findings (an untested scenario counts as
CRITICAL) and `findings` to the findings list with file:line evidence.
