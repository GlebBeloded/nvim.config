## Current render

**Current**: `80x1`, excerpt: bottom row, Normal mode, `cmdheight=0`, `<A-9>` pressed and menu waiting

```text
 NORMAL  ⎇ loop/fix-ai-menu-prompt-hidden                    ✗ 0 ▲ 0  ◆ lua 
```

The statusline remains on the bottom row; the menu choices are not visible.

## Proposed render

**Proposed**: `80x1`, excerpt: bottom row, Normal mode, initial `cmdheight=0`, `<A-9>` pressed and menu waiting

```text
99> [s]earch [v]ibe: █                                                          
```

The temporary message row exposes the existing one-key menu. `cmdheight` returns to its prior value after the key is read.

## Decisions

- Temporarily set `cmdheight` to one only for the echo and blocking key read, restoring the prior value before dispatch.
- Keep the message-area menu instead of adding a float or `vim.ui.select`; this preserves the specified one-key interaction and `Question` highlight.
- The existing integration scenario is the acceptance test. The change does not add a new reference-screenshot scenario because the prompt text, not visual styling, is the behavior under repair.
