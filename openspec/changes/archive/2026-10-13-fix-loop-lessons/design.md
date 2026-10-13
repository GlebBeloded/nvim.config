# Design

## Context

See `proposal.md` — Why. The build loop uses fresh agent context and only exposes the immediately previous pass to `implement`. `gate.py` runs after implementation, `verdict.py` runs once per pass, and `escalation.py` runs after the loop. All three receive the run artifact directory; repository edits made before escalation are included by its existing `git add -A`.

Rule 10 permits operational guidance in `docs/workflow.md` but not a new standalone documentation path. The lesson memory must therefore remain part of that file while being machine-editable without rewriting unrelated prose.

## Goals / Non-Goals

**Goals:**

- Preserve a small set of verified cause-to-action lessons across runs.
- Keep lesson selection agent-authored but make storage, normalization, deduplication, and trimming deterministic.
- Make both bug exploration and implementation consume the same source before task work.

**Non-Goals:**

- Treating raw test output as a lesson or using an LLM inside verdict/escalation.
- Replacing per-pass `$LOOP_PREV` feedback or changing context/session policy.
- Maintaining a complete incident history; archived changes and run artifacts keep that detail.

## Decisions

### Keep a bounded section in `docs/workflow.md`

Add `## Loop lessons` with at most 10 one-line bullets. Seed it with the three proven recurring rules: load-scaled timing budgets, waiting for asynchronous git commit outcomes before assertions, and serializing/resetting the shared sandbox VM.

The writer locates the heading and the next level-two heading, replaces only the bullet block, and leaves all other bytes unchanged. This follows rule 10, travels with the branch, and is visible during normal loop operation.

Alternatives rejected:

- A new `docs/lessons.md`: rule 10.3 does not permit that path.
- Run artifacts only: they are per-run and are not read by later runs.
- `AGENTS.md`/`docs/CLAUDE.md`: every agent would receive changing operational details, while only fix/build agents need them.

### Separate lesson judgment from deterministic persistence

After loading skills and reading existing lessons, `implement` examines the previous pass feedback. When it fixes one of those failures and verifies the correction with the targeted test or command, it appends one concise cause-to-action line to `$ARTIFACTS_DIR/lesson-candidates.txt`. It writes nothing when there is no earlier failure or no verified correction.

A shared Python helper used by verdict and escalation consumes candidate lines, collapses whitespace, rejects empty/multiline content, compares with `casefold()`, moves a repeated equivalent to the newest position without duplicating it, and retains the 10 newest lessons. Verdict invokes it after each pass; escalation invokes it again idempotently so a final exhausted pass cannot lose a verified partial recovery.

This division keeps the semantic question (“what did this attempt learn?”) with the agent that made and verified the correction, while scripts own the mechanical safety properties.

Alternatives rejected:

- Derive lessons from the last 40 lines of gate logs: log phrasing is unstable and does not contain the corrective action.
- Let `implement` edit `docs/workflow.md` directly: an unverified or duplicated claim could become durable before the verdict path.
- Add a separate AI reflection node: it adds another model call and still needs the same deterministic writer.

### Prompt order is skill load, lessons, then task context

The existing commands must load declared skills before any other step. Immediately after that block, `explore-bug` and `implement` read `docs/workflow.md`'s `Loop lessons` section; only then do they inspect the bug/change and begin work. The prompt-reference test checks both the path/heading and this ordering.

### Test scripts through a throwaway checkout

Add `tests/unit/loop/test_lessons.lua`. It invokes the Python writer through `vim.system` against a temporary `docs/workflow.md`, so append, deduplication, trimming, and preservation of surrounding text are observable without mutating the checkout. The prompt scenario reads the real command sources.

## Risks / Trade-offs

- [An agent writes a vague or incorrect candidate] → require a prior-pass failure, a cause-to-action sentence, and direct verification before writing; persistence remains reviewable in the branch diff.
- [Concurrent runs add different lessons on separate branches] → normal ship/reconcile handles the Markdown conflict; exact duplicates are removed when either branch next runs the writer.
- [Automatic trimming drops useful history] → keep the newest 10 operational lessons; detailed history remains in archived changes and run artifacts.
- [A malformed section could overwrite prose] → fail without writing unless exactly one heading and a following level-two boundary are found; tests pin preservation outside the section.

## Migration Plan

Create the section with the three curated lessons in the same change that introduces the writer and prompt references. No data migration is needed. Rollback removes the prompt/writer wiring and the section; run artifacts remain unaffected.
