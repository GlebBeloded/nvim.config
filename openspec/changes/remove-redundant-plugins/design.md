# Design

## Context

See proposal.md (Why). Root cause, checked with the full config in tmux (60x8, `sample.lua` committed
in a temp repo, working copy adds line 2):

- `init.lua` runs `require("gleb.plugins")` (lazy.nvim setup) before `require("gleb.options")`.
  mini.diff has no lazy trigger, so `setup({})` runs while `vim.go.number` is still false and
  `MiniDiff.config.view.style` resolves to `"sign"`.
- Line 2 carries two sign extmarks: `MiniDiffViz` `▒` [MiniDiffSignAdd] and `gitsigns_signs_` `┃`
  [GitSignsAdd]. `signcolumn = "yes"` holds one sign, and mini.diff's priority (199) beats gitsigns'
  (6), so `▒` is drawn.
- `:lua MiniDiff.disable(0)` in the same session brings back `┃`: gitsigns itself is fine.
- The spec scenario "Added line shows bar sign" is not covered by a test, and an extmark check
  alone would pass either way. A screen test closes that gap.

impatient.nvim has no visible effect. Nothing requires it, and `vim.loader.enable()` replaces it.

## Goals / Non-Goals

**Goals:**
- gitsigns is the only source of hunk signs, and a screen test asserts what is drawn.

**Non-Goals:**
- Moving `gleb.options` before `gleb.plugins` in `init.lua`. That would make mini.diff color line
  numbers instead, and it would still duplicate gitsigns.
- Changing gitsigns' sign priority or `signcolumn`.

## Decisions

### D1. Remove mini.diff instead of reconfiguring it
- Alternative: keep mini.diff with `view.style = "number"` or a lower priority. Rejected: two hunk
  sources would still disagree on refresh timing and base, and nothing in the config uses mini.diff's
  overlay or keymaps.
- Alternative: drop gitsigns for mini.diff. Rejected: the git spec, `:Gitsigns` and the statusline
  diff counts build on gitsigns.

### D2. Remove impatient.nvim
It is dead weight: never required, and Neovim's built-in `vim.loader.enable()` (`options.lua`)
covers it. No test change. The smoke test's plugin load and healthchecks prove nothing depended on it.

### D3. Screen test on rows 2-5 only
The screenshot covers the buffer rows (rows 2-5 at 60x8). The bufferline and statusline rows are left
out so the test does not break on unrelated chrome changes. The repo is a temp `git init` with a fixed
commit, so the text is deterministic. A `git-hunk` render case drives the same state for
`make render`.

## Renders

**Current**: `60x8`, excerpt: rows 2-5, Normal mode, `sample.lua` in a temp git repo, line 2 added
and not committed, cursor at 1:1

```text
  1   █ocal M = {}
▒   1 M.x = 1
    2
    3 return M
```

[MiniDiffSignAdd] on `▒`; gitsigns' [GitSignsAdd] `┃` is hidden under it.

**Proposed**: same size and state

```text
  1   █ocal M = {}
┃   1 M.x = 1
    2
    3 return M
```

[GitSignsAdd] on `┃`. Only the glyph and its group change. All other cells are identical, so no
mask is needed. This is the expected text of the reference screenshot for "git: Added line sign
matches reference screenshot".

## Risks / Trade-offs

- [mini.diff's `gh`/`[h` maps disappear] → never used in this config; `:Gitsigns` covers them
  (proposal, Impact).
- [gitsigns refreshes asynchronously, so the screenshot may be taken before the sign appears] → the
  test waits until a `gitsigns_signs_` extmark exists on line 2 before it captures.
- [stale lazy-lock entries keep the plugins installed on disk] → `lazy-lock.json` entries removed;
  `:Lazy clean` removes the directories. The test sandbox installs fresh.
