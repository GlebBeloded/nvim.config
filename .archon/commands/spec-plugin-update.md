---
description: Turn a plugin update that breaks make check into an OpenSpec change
---
# Specify the adaptation

First, load each of these skills before any other step: `superpowers:systematic-debugging`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $systematic-debugging. Report each skill as it loads. If one does not
load, stop and report the error naming it.

Flow (plugin-adapt): context + changelog → **diagnose + spec** → plan → implement ×task → check → fix → review → judge → ship.
Your step: **diagnose + spec**. Input: the plugin changelog and failures. Output: the change folder and the JSON fields. Do not: write tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Plugin: $INPUTS.plugin, pinned $INPUTS.old, updated to $INPUTS.new (lazy-lock.json in this worktree
already has the new commit; the tests run against it).
Change id: $INPUTS.change
Changelog: $ARTIFACTS_DIR/changelog.md. Failing gate: $ARTIFACTS_DIR/check-update.log

Find the root cause with `superpowers:systematic-debugging` (phase 1-3, no code changes): which
commit of the changelog breaks which test, and why. Read the plugin's code at the new commit under
.tests/xdg/data/nvim/lazy/$INPUTS.plugin/.

If openspec/changes/$INPUTS.change/ exists (an earlier update was pinned back), update it for the
new commit range with openspec continue-change; otherwise create it with openspec propose.
Follow openspec/config.yaml rules:
- proposal: `Kind: bug`, upgrades the $INPUTS.plugin dependency (both commits, compare link), the
  failing tests and error excerpt, the root cause, what the config must adapt; core keymap change?
  out of scope.
- spec delta: the behaviour the user keeps with the new version, as MODIFIED or ADDED scenarios.
  Never remove or weaken a scenario.
- tasks.md: each task names its scenario titles; its first step is the failing test (a test that is
  red now counts).

Do not change code, tests or lazy-lock.json. Stop after the artifacts exist.
