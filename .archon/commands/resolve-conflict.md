---
description: Merge auto into the run branch and resolve the conflicts ship reported
---
# Resolve conflict

Change id: $INPUTS.change
Files ship reported as conflicting with `auto`: $ship.output.files

`ship` could not merge this run's branch into `auto`: `auto` changed the same lines since the branch
was cut. Work only in this run worktree; never touch the `auto` checkout (`~/.config/nvim`).

1. `git merge auto`. Resolve every conflict keeping the intent of both sides: the run's change and
   what landed on `auto`. Keep every test and every scenario from both; never delete, skip or weaken
   one to make the merge fit.
2. `make fmt`, then `make quick` until it is green.
3. Commit the merge (`git commit --no-edit`).

If the two intents cannot both hold, keep the branch as is and say why; the run fails with the
branch kept.
