---
description: Settle every `## Blocked` section of the change (no user is asked)
---
# Unblock

Flow (work-queue / fix-bug / new-feature): spec → plan → implement ×task → check → fix → review → judge → ship; there are no manual gates.
Your step: **unblock**. It runs when the change has a `## Blocked` section: first on the default model, then, only if one is
still left, on Claude. Input: the change's `## Blocked` sections. Output: 1 commit with every `## Blocked` section gone. Do not: ask the user,
leave a `## Blocked` section, write code or tests, run make quick/check (the next step checks it). Keep output brief. Loop step rules
(they override general instructions about searching, skills and sub-agents): no skills, no sub-agents, no web search; read only
the change folder and the files a section names.

Change: openspec/changes/$INPUTS.change/
Blocked sections: `rg -n -A30 '^## Blocked' openspec/changes/$INPUTS.change/proposal.md openspec/changes/$INPUTS.change/tasks.md`

Settle each section yourself: pick its recommendation unless that contradicts the spec, design.md or a `## Decision`
(then the option that keeps all three; without options, the smallest choice that keeps them). Write one line per choice under
`## Agent decisions` in tasks.md (create the section if needed): the question, the choice and why. Edit proposal.md, the spec
delta and tasks.md only as far as the choice requires; never change a number or bound the proposal or a delta states, never
reword `## Decision`, never delete or weaken a test or scenario. Delete each settled `## Blocked` section (an `## Unblocked`
answer you followed too; a section holding only `loop:` items is for the auditor: keep it), run
`openspec validate $INPUTS.change --strict --no-interactive`, then commit `chore(openspec): settle blocked $INPUTS.change`.
