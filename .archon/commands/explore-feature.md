---
description: Explore and brainstorm a feature idea before proposing it
argument-hint: <feature idea>
---
# Explore the idea

First, load each of these skills before any other step: `openspec-explore`, `superpowers:brainstorming`.
On Claude, load each with the Skill tool. On Codex, invoke each by name: $openspec-explore, $superpowers:brainstorming.
Report each skill as it loads. If one does not load, stop and report the error naming it.

Idea: $ARGUMENTS

Use the `openspec-explore` skill, then `superpowers:brainstorming`, without asking the user
questions: nobody is at the console during this node. Where you would ask, pick the option that
fits docs/CLAUDE.md and docs/architecture.md (Conventions) best and record the alternatives.
Research plugins (GitHub, awesome-neovim; stars, last commit) before proposing custom code.

Write `$ARTIFACTS_DIR/brainstorm.md`: problem, options with trade-offs, recommendation, open
questions. Do not edit the repository.
