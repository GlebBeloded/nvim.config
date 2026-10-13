## Context

See proposal.md (Why). Screen tests compare mini.test screenshots, which keep only attribute identity
per cell (`screenattr` ids, renumbered). `H.statusline_colors` gets colors from
`nvim_eval_statusline` instead of from the screen, so it works only for the statusline and only for
the first match of a string.

Root cause of the gap: the per-cell colors the child actually drew are never read. Reading them has a
catch, found while checking the proposal's `nvim__inspect_cell` probe inside a real mini.test child
(full config, `lua-file` render case, NVIM v0.12.5):

- The child has no UI attached (`nvim_list_uis()` is `{}`).
- The **first** `nvim__inspect_cell` call in a child returns the correct attributes. Every call after
  it returns unrelated ones for the same cell and the same `screenattr` id. Cell 0 of the statusline
  returned `lualine_a_normal`, and the next call returned `{ foreground = 0xa9b665 }`. The first call
  switches the highlight table to another state, so the attr ids already in the grid point to other
  entries.
- After that first call plus `redraw!`, every cell of the row matches its group (`lualine_a_normal`,
  `lualine_c_normal`, `lualine_x_diagnostics_{error,warn}_normal`, `StatuslineLangText`,
  `StatuslineLang_lua`) on repeated reads.
- A cell drawn in default colors returns no `foreground`/`background` key.

## Goals / Non-Goals

**Goals:**
- One assertion that checks the drawn colors of every cell on any screen row against a mask + legend
  (the design-render notation), with highlight group names instead of hex literals.
- Statusline screen tests check the whole row in Normal and Insert mode.

**Non-Goals:**
- Changing the reference screenshot format or mini.test.
- Attaching a UI to the child.
- Parsing masks out of design.md files at test time (a change's design is archived; tests embed their
  mask).

## Decisions

### D1. Read colors with `nvim__inspect_cell` after a priming call and `redraw!`
The child-side reader calls `nvim__inspect_cell(1, 0, 0)` once, runs `redraw!`, and then reads every
cell of the requested rows in the same `child.lua` call. It does this on every call, because each
`start` is a new process.
- Alternative: compute colors per cell from sources (`nvim_eval_statusline` for statusline, tabline
  and winbar; `vim.inspect_pos` for buffers). Rejected: it rebuilds Neovim's highlight stacking
  (extmark priority, winhighlight, floats, blend), and it is the same blind spot again, since it
  checks the inputs and not what was drawn.
- Alternative: attach an RGB UI to the child over RPC and read the `hl_attr_define`/`grid_line`
  events. Rejected: the host Neovim cannot consume `redraw` notifications on a job channel, and an
  attached UI changes sizing and the behaviour every other test runs under.
- `nvim__inspect_cell` is an internal API (`__`), so it is wrapped in one child-side chunk in
  `tests/helpers.lua` and nowhere else.

### D2. API: `H.expect_screen_colors(child, row, mask, legend)`
- `row`: a screen row as in `H.screen_rows` (negative counts from the bottom, `-1` is the statusline
  with `cmdheight=0`). `mask`: `string[]`, one string per row from `row` downward, exactly
  `columns` cells each (checked with `strchars`; a wrong width fails with a message).
  `legend`: `table<string, string>`, letter -> exact highlight group name.
- Same notation as design renders: `.` or space is [Normal]. The approved render's mask and legend
  are copied into the test unchanged.
- Expected per letter: `nvim_get_hl(0, { name = group, link = false })`, read in the child after the
  screen is drawn (groups such as `StatuslineLang_lua` exist only after the first draw). An
  undefined group fails, naming the letter and group.

### D3. Compare only what the legend group defines
Per cell, compare `fg`, `bg` and `sp` only where the group sets them. Missing colors in the actual
cell are filled from Normal. Flags (`bold`, `italic`, `underline`, `undercurl`, `strikethrough`,
`reverse`) are always compared, absent meaning false.
- Reason: fg-only groups that Neovim stacks on a segment (for example `StatuslineLangCapOk` over the
  chip background) can then be named directly. A wrong fg is still caught, and so is a wrong bg
  wherever the group sets one.
- Alternative: fill the expected side from Normal, as `make colorize` does for display. Rejected:
  every stacked fg-only group would fail.

### D4. Failure output is a mask diff
On mismatch, build the **actual** mask: each cell gets the first legend letter (in sorted order) whose
expected attributes match, else `?`. Fail with expected and actual mask rows one above the other,
followed by the first mismatching cell: column, character, expected group, and expected and actual
attributes as `#rrggbb`. The agent sees where the color is wrong, in the same notation it writes.

### D5. Share notation constants with `make colorize`
Move `DEFAULT_GROUP` (`Normal`) and the unmasked letters (`.`, space) from `tests/render/colorize.lua`
to `tests/helpers.lua`. Colorize already requires the helpers. The markdown parsing stays in
colorize.

### D6. Remove `H.statusline_colors` / `H.expect_colors`
After the statusline tests move to masks, nothing calls them. A full-row mask covers a single segment
too, so keeping them would leave two ways to check colors. This overrides the proposal's "keep"
bullet, and proposal.md is updated to match.

### Expected mask for the Normal-mode statusline
Built from the probe above. The Insert-mode mask is read off the screen during implementation in the
same way, with group names, not hex.

**80x1, Normal mode, excerpt: statusline row, sample.lua, no LSP, outside git (lua-file case)**

```text
 NORMAL                                                          ✗ 0 ▲ 0  ◆ lua 
```

```text
aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccceeeeewwwwtlttttt
```

Legend: `a` [lualine_a_normal] · `c` [lualine_c_normal] · `e` [lualine_x_diagnostics_error_normal] ·
`w` [lualine_x_diagnostics_warn_normal] · `t` [StatuslineLangText] · `l` [StatuslineLang_lua]

No screen output changes, so this change has no Current/Proposed render pair. The block above is the
expected value of the new assertion, not a UI proposal.

## Risks / Trade-offs

- [`nvim__inspect_cell` or the priming behaviour changes on nightly] → it lives in one helper chunk.
  The statusline screen tests fail loudly with a mask diff instead of passing silently. Fall back to
  D1's first alternative if the API is removed.
- [`redraw!` before reading changes what a timer-driven component shows (LSP progress, spinner)] →
  callers wait for a stable screen first, as `expect_statusline_screenshot` already does. The text
  screenshot is taken before the color read.
- [A mask has no self-test, because a helper test would be a `make trace` orphan] → while
  implementing, change one legend letter and check that the statusline test fails with a readable
  diff, then revert. The un-primed read already fails the real row, which shows the check is not
  color-blind.
- [Masks are 80 cells wide and tedious to edit] → the failure output prints the actual mask in the
  same format, ready to review and paste after an intended change.

## Migration Plan

Test-only. Statusline screen tests switch in the same commit that adds the helper. The reference
screenshots stay as they are. Rollback is a revert.
