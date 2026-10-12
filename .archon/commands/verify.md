---
description: Verify implementation against the change artifacts (/opsx:verify)
---
# Verify

Change id: $INPUTS.change

Run the `openspec-verify-change` skill for this change, non-interactively. Also run `make trace
VERBOSE=1` and check that every scenario the change adds or modifies is `tested`.
Do not edit files. Set `critical` to the number of CRITICAL findings (an untested scenario counts as
CRITICAL) and `findings` to the findings list with file:line evidence.
