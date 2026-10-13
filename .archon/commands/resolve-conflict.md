---
description: Merge auto into the run branch and resolve the conflicts ship reported
---
# Resolve conflict

Flow (port): merge auto in → **resolve** → check → fix → ship.
Your step: **resolve**. Input: the conflict hunks. Output: 1 merge commit with no conflict markers. Do not: change behaviour beyond merging both sides, drop tests, run make quick/check. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Change id: $INPUTS.change
Files ship reported as conflicting with `auto`: $ship.output.files
Static gates failed on the clean merge: $ship.output.gate_failed
Gate output: $ship.output.log

`ship` could not merge this run's branch into `auto`: `auto` changed the same lines since the branch
was cut, or (gate failed true) the merge is clean but `make lint trace specs` fails on it, e.g. a
test case name both sides added. Work only in this run worktree; never touch the `auto` checkout
(`~/.config/nvim`).

1. `git -c merge.conflictStyle=zdiff3 merge auto` (hunks then show the base between `|||||||` and `=======`). Resolve every conflict keeping the intent of both sides: the run's change and
   what landed on `auto`. Keep every test and every scenario from both; never delete, skip or weaken
   one to make the merge fit.
   A side may have deleted lines: read each conflicted file's base (`git diff --merge <file>` or `git show :1:<file>`) and apply both sides' changes to it, deletions included; an empty side in a hunk is often a deletion, not "nothing".
2. On a gate failure, fix what the gate output names (rename a duplicated case, keep both tests) and
   rerun `make lint trace specs`.
3. `make fmt`; run only the test files that conflicted (`make test FILE=… 2>&1 | tail -40`); the gate runs `make check`.
4. Commit the merge (`git commit --no-edit`).

If the two intents cannot both hold, keep the branch as is and say why; the run fails with the
branch kept.
