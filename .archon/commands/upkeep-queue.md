---
description: File plugin breakages found by weekly-upkeep as queue items
---
# Queue the breakage

Pinned plugins (old = pinned commit, new = breaking commit): $INPUTS.culprits
Failing logs: $ARTIFACTS_DIR/check-*.log

For each plugin, create a change with `openspec new change fix-upkeep-<plugin>` (kebab-case) and
write only its proposal.md: `Kind: bug`, the plugin, both commits, the failing test names and the
error excerpt, a link to the plugin's commit range on GitHub, and "Pinned back in lazy-lock.json by
weekly-upkeep". Do not change code or lazy-lock.json; the work-queue workflow takes it from here.
