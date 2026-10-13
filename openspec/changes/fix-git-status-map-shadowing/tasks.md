# Tasks

Notes for all tests: open the tree with `cd <modified_repo()> | enew | Neotree git_status` and wait for `a.txt` as in "q closes preview and tree" (`tests/integration/file-tree/test_tree.lua`). Put the cursor on `a.txt` with `vim.fn.search("a.txt")`, not `j`: `j` in this tree opens a diff preview. Call `child.wait_very_lazy()` before you read the global `gr`.

## 1. Revert on X, gr freed

Scenarios: "X reverts a file after confirmation", "X keeps a file when revert is declined", "gr keeps its global meaning in git status tree".

- [x] 1.1 Add `T["file-tree: X reverts a file after confirmation"]`, `T["file-tree: X keeps a file when revert is declined"]` and `T["file-tree: gr keeps its global meaning in git status tree"]` to `tests/integration/file-tree/test_tree.lua`. The two `X` cases wait for the neo-tree confirm popup (NuiInput, prompt ` y/n: `), type `y<CR>` / `n<CR>`, then assert `a.txt` content and `git status --porcelain`. The `gr` case asserts `maparg("gr","n",false,true).buffer == 0` and that its callback is `require("telescope.builtin").lsp_references`, as `callback_is` does in `tests/integration/keymaps/test_keymaps.lua`. Run `make test FILE=tests/integration/file-tree/test_tree.lua` and verify all three fail.
- [x] 1.2 In the `git_status` `window.mappings` of `lua/gleb/file_tree/init.lua`, replace `["gr"] = "git_revert_file"` with `["X"] = "git_revert_file"` and `["gr"] = "none"`. Neo-tree's default `gr` binding is removed and the built-in confirmation is kept (design: Decisions). Verify that the three cases pass and `make quick` is green.

## 2. AI commit on gc, c is copy, help labels

Scenarios: "gc commits confirmed message", "c is copy in git status tree", "Help lists the moved git status keys".

- [ ] 2.1 Add `T["file-tree: gc commits confirmed message"]` and `T["file-tree: c is copy in git status tree"]` to `tests/integration/file-tree/test_tree.lua`.
  - For `gc`: stage `a.txt` in the temp repo and stub `gleb.git.ai_commit.show_commit_input` so it confirms `feat: x`. Assert `git log -1 --format=%s` and a captured `vim.notify` call `Committed: feat: x` at INFO.
  - For `c`: find the `c` entry in `nvim_buf_get_keymap(0, "n")` and assert its `desc` is `copy`.
- [ ] 2.2 Add `tests/screen/file-tree/test_git_status_help.lua` with `T["file-tree: Help lists the moved git status keys"]`.
  - Use a 100x40 child (`child.set_size(40, 100)`).
  - Create the repo at a fixed path, with the file `lua/gleb/file_tree/init.lua` modified. Recreate the path on each run so the `GIT STATUS for` header is deterministic.
  - Run `:Neotree git_status`, then `?`.
  - Before `H.expect_screenshot`, assert that the screen text contains the rows `X -> git_revert_file`, `c -> copy` and `gc -> commit (AI)`, and has no `gr ->` row. A missing reference screenshot passes on its first run, so this text check is the part that fails before the fix.
  - Verify that the three cases fail.
- [ ] 2.3 In `lua/gleb/file_tree/init.lua`, remove `["c"] = git_commit` so the common `c = "copy"` applies, and add `["gc"] = { git_commit, desc = "commit (AI)" }`. Verify that the three cases pass. The screen case writes its reference to `tests/screenshots/` on the first run.
- [ ] 2.4 Check the new reference screenshot against the Proposed render in design.md (help rows and order, apart from the header path) and commit it. Verify that `make test-screen` passes on a second run.

## 3. Integration

- [ ] 3.1 Run `make trace` and verify that the six new scenarios show as tested and there are no orphans.
- [ ] 3.2 Run `make check` and verify it is green, with no test or scenario removed or weakened.

## Workflow follow-up

- Archive after review. If fix-neotree-commit-check archives later, rebase its delta onto "Git status AI commit and push" (`c` → `gc`).
