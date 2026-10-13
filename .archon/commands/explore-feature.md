---
description: Explore and brainstorm a feature idea before proposing it
argument-hint: <feature idea>
---
# Explore the idea

First, load each of these skills before any other step: `superpowers:brainstorming`. On Claude, load each with the
Skill tool. On Codex, invoke each by name: $brainstorming. Report each skill as it loads. If one does not
load, stop and report the error naming it. The skill text is already in your context once loaded: do not re-read its SKILL.md.

Flow (new-feature): brainstorm → spec + renders → user picks a render → plan → implement ×task → check → fix → review → judge → ship.
Your step: **brainstorm**. Input: the idea. Output: `$ARTIFACTS_DIR/idea.md`, at most 15 lines (options, pick, why). Do not: write specs, tests or code. Keep output brief. Loop step rules (they override general instructions about searching, skills and sub-agents): use only the skill named above, no sub-agents; search the web only for facts that are in neither the repo nor the installed plugin source; read doc sections you need (`rg -n '^## ' <doc>`, then that range), never whole docs.

Idea: $ARGUMENTS

Use the openspec explore skill, then `superpowers:brainstorming`, without asking the user
questions: nobody is at the console during this node. Where you would ask, pick the option that
fits docs/CLAUDE.md and docs/architecture.md (Conventions) best and record the alternatives.
Research plugins (GitHub, awesome-neovim; stars, last commit) before proposing custom code.

Write `$ARTIFACTS_DIR/brainstorm.md`: problem, options with trade-offs, recommendation, open
questions. Do not edit the repository.
