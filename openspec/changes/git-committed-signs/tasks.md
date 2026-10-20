## 1. Pure kinds and mapping

Scenarios: `git: Committed signs kinds and mapping follow the unit table`, `git: Committed signs map a large buffer quickly`

- [x] 1.1 Write the rows of design.md Decision 4 and the 10 000-line timing case in tests/unit/git/test_committed_map.lua (bare child), and see them fail.
- [x] 1.2 Add `lua/gleb/git/committed_signs/map.lua`: `kinds(base_lines, head_lines)` and `to_buffer(head_lines, buf_lines, kinds)`, both with the diff options of Decision 3. It is pure and typed (rule 1.3).
- [x] 1.3 Run `make test FILE=tests/unit/git/test_committed_map.lua` and see it pass.

## 2. Signs in buffers

Scenarios: `git: Committed signs mark the branch's lines`, `git: Committed signs mark every line of a file added on the branch`, `git: Committed signs mark deleted lines`, `git: Committed signs colour is gruvbox purple`, `git: Committed signs are absent without a base`, `git: Committed signs skip files the branch did not change`, `git: Committed signs compare a renamed file with its old path`, `git: Committed signs skip a file over the line limit`

- [x] 2.1 Write the scenarios in tests/integration/git/test_committed_signs.lua. Use `F.copy("prbranch", …)` and the repos of design.md Decision 9. "no `git cat-file` ran" is read from a `vim.system` recorder the case installs in the child. See them fail.
- [x] 2.2 Add `lua/gleb/git/sign_text.lua` and point `gitsigns.lua` at it (same characters; `grep -n '= ""'` stays empty, rule 9.5).
- [x] 2.3 Add `lua/gleb/git/committed_signs/init.lua` (Decisions 1 and 5-8): the augroup, the `GitCommittedSign` highlight with its `ColorScheme` refresh, the changed-file list, blob reads by oid with the binary and size limits, and the extmarks. Require it from `lua/gleb/git/init.lua` after `gleb.git.gitsigns`, with the order comment.
- [x] 2.4 Run `make test FILE=tests/integration/git/test_committed_signs.lua` and see these pass.

## 3. Following the buffer and the base

Scenarios: `git: Committed signs move with unsaved edits`, `git: Committed signs yield to a local change on the same line`, `git: Committed signs refresh after a commit`, `git: Committed signs appear when a root gains a base`, `git: Committed signs clear when HEAD is detached`

- [x] 3.1 Add the scenarios to tests/integration/git/test_committed_signs.lua and see them fail.
- [x] 3.2 Implement Decision 6: `nvim_buf_attach` with a debounced re-map, the `User GlebGitBaseChanged` recompute or clear, and teardown on `BufWipeout`/`on_detach` with current-key checks on async results (rules 6.3 and 6.5).
- [x] 3.3 Run the file and see every scenario in it pass.
- [x] 3.4 Pass the repository root to `base.resolve` callbacks, keep it for each buffer when base resolution returns no Info, and cover the no-base-to-base transition.

## 4. Screen

Scenarios: `git: Committed signs match the approved render`

- [x] 4.1 Add the `committed-signs` case to tests/render/cases.lua (Decision 10). Write tests/screen/git/test_committed_signs_screen.lua: text screenshot plus `H.expect_screen_colors` on columns 1-6 of rows 2-29 with the mask and legend of "Proposed — committed signs". See it fail.
- [x] 4.2 Make it pass. Review the new reference screenshot against the Proposed text (real glyphs where the render has stand-ins), and compare `make render CASE=committed-signs COLUMNS=100 LINES=30` with `renders/proposed-committed-signs.ansi`.

## Agent decisions

- Encode the gutter mask using Neovim's full sign and number-column cell attributes; this preserves the approved visible colours while covering padding cells consistently with the existing git screen test.
- Wait for lualine's own diff source and refresh it before capture, because it updates independently of the gitsigns extmarks.

## 5. Gate

Scenarios: `git: Added line shows bar sign`, `git: Added line has no competing hunk sign`, `git: Added line sign matches reference screenshot`, `git: Blame is off by default`, `git: Missing optional git plugins are tolerated`

- [x] 5.1 Re-run `grep -rn "H.root" tests/screen`. Every case that opens a file must open a fixture copy or a temp repo, never this checkout (design.md Risks).
- [x] 5.2 Run `make quick`, then `make check`. `make smoke` keeps its startup budget and shows no new message.
- [x] 5.3 `make trace` lists every new scenario as tested, and `make colorize FILE=openspec/changes/git-committed-signs/design.md` reports only `GitCommittedSign` as unknown until the code defines it.
