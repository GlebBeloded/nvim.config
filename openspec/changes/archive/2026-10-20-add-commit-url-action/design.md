## Current render

`100x30`, Normal mode, Find Action opened from a Branch commit row with query `commit url`:

```text
             ╭ Find Action › commit url█───────────────────────────────────────────────╮
             │                                                                        │
             │ Assign ⌥↩ · Show hidden ⌘⇧A                                        0/0 │
             ╰────────────────────────────────────────────────────────────────────────╯
```

No commit-specific action is offered.

## Proposed render

`100x30`, Normal mode, Find Action opened from a Branch commit row with query `commit url`:

```text
             ╭ Find Action › commit url█───────────────────────────────────────────────╮
             │ Copy Commit URL                                                Changes │
             │ Assign ⌥↩ · Show hidden ⌘⇧A                                        1/1 │
             ╰────────────────────────────────────────────────────────────────────────╯
```

The row is contextual: opening Find Action from a file row or the Branch files view retains the current empty
result. The action has no shortcut, so no shortcut glyph is drawn.

## Interaction

Selecting `Copy Commit URL` closes Find Action, restores the originating Changes panel context, and copies the full
commit URL. No browser is opened and the Changes panel remains on the selected commit.
