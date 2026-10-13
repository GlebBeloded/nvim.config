# Design

## Context

See `proposal.md` for motivation and `specs/git/spec.md` for required behavior. The ranged command currently creates a temporary linewise Visual selection. Leaving that selection updates `'<` and `'>`, and an unprotected permalink call can bypass all cleanup when it errors.

## Goals / Non-Goals

**Goals:**
- Treat the temporary selection as command-local state and restore editor state on both success and failure.
- Preserve the original permalink failure after cleanup.

**Non-Goals:**
- Change gitlinker configuration, URL generation, keymaps, or module wiring.

## Decisions

### Snapshot and restore all affected editor state

Before creating the temporary selection, capture the cursor and both visual selection marks. After leaving Visual mode, restore the cursor and marks. Restoring marks after leaving Visual mode is required because leaving Visual mode itself writes those marks.

Alternative: derive the previous selection from mode or command range. Rejected because an explicit Normal-mode range is unrelated to the user's previous visual selection.

### Protect only permalink generation and clean up before rethrowing

Run permalink generation as a protected call, perform the same cleanup regardless of its result, then rethrow the captured error without adding a new stack location.

Alternative: suppress the error after cleanup. Rejected because it would hide the command failure and change existing error semantics.

## Risks / Trade-offs

- [Restoration order accidentally rewrites the saved marks] → Exit the temporary selection before restoring the saved cursor and marks, and cover the order with integration scenarios.
- [Protected execution obscures the original error] → Re-raise the captured value without decorating it.
