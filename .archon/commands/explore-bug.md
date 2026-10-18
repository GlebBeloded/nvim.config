---
description: Find the root cause of a reported bug (no fixes)
argument-hint: <bug description or openspec change id>
---
# Explore the bug

First, load each of these skills before any other step: `superpowers:systematic-debugging`. On
Claude, load each with the Skill tool. On Codex, invoke each by name:
$systematic-debugging. Report each skill as it loads. If one does not load, stop and
report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (fix-bug / work-queue): diagnose → spec → plan → implement ×task → check → fix → review → judge → ship.
Your step: **diagnose**. Input: the bug text. Output: `$ARTIFACTS_DIR/root-cause.md`, at most 12 lines. Do not: write specs, tests or code; plan tasks. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Read the `## Loop lessons` section in `docs/workflow.md` before reading the bug context or
investigating the project.

Bug: $ARGUMENTS

Use the `superpowers:systematic-debugging` skill (phase 1-3 only: reproduce, trace, root cause).
Context: docs/CLAUDE.md, docs/architecture.md, docs/testing.md, the capability spec in
openspec/specs/<capability>/spec.md and the queued changes in openspec/changes/. If the input is a change id, read
openspec/changes/<id>/ first.

Start from the files and functions the bug names (`rg -n` and line ranges read once with `nl -ba`, not whole files; narrow `rg` patterns); plugin source is under `~/.local/share/nvim/lazy/<plugin>`. Reproduce in a headless child Neovim where possible (`make test CASE=…`, or a throwaway mini.test
case you delete afterwards). Do not change code, specs or tests. Ad-hoc headless runs: write the probe to a scratch file and run `make probe SCRIPT=$ARTIFACTS_DIR/probe.lua` (the tests' full-config child and sandbox, prints its output and return values, non-zero on error, `PROBE_TIMEOUT` ms); do not hand-build rtp or XDG dirs. LSP restart and tree and panel renders are async: wait for the end state, not for attachment. Visual marks need `exe "normal! V2j\<Esc>"` or `nvim_buf_set_mark`.

Write `$ARTIFACTS_DIR/root-cause.md`: symptom, reproduction, root cause with file:line evidence,
affected capability, and the correct behaviour as a WHEN/THEN sentence. Drop anything you could not
prove. If the bug cannot be reproduced or the input is ambiguous, say so in the file and stop.
