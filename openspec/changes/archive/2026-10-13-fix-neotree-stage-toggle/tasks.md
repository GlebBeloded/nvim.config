## Conventions for this change

- Layer: integration (real config, real neo-tree). File: `tests/integration/file-tree/test_stage.lua`, a fresh `child.start_config()` + `child.wait_very_lazy()` per case, codediff stubbed as in `test_diff_preview.lua` (`stub_codediff_view`: `require("codediff.ui.view").create = function() vim.cmd("tabnew") end`) so cursor moves in the tree never crash.
- Repo helper `staging_repo(files)`: like `modified_repo()` in `test_tree.lua`: temp dir, `git init -q`, write and commit the given files (`git -c user.name=t -c user.email=t@t commit -qm init`), return the dir. Each case then modifies/stages with host `vim.system(..., { cwd = dir }):wait()`. `staged(dir)` returns the lines of `git diff --cached --name-only` run in `dir`.
- Opening: `child.cmd("cd " .. dir .. " | enew | Neotree git_status")`, or for the cwd-outside cases `cd` to a fresh non-repo `vim.fn.tempname()` dir and `Neotree git_status dir=<repo>`.
- Cursor: `child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.lua", "nw") > 0]], ASYNC_MS)`, then put the cursor on the exact node line with `vim.fn.search([[\<a\.lua$]], "w")`, then `child.type_keys(" ")`. Poll `staged(dir)` with `vim.wait` up to `ASYNC_MS` (`ASYNC_MS = 3000`).
- Notifications: replace `vim.notify` in the child with a recorder (`Notes = {}`, as in `test_diff_preview.lua`) before pressing the key.

## 1. Exact path staging with failure reporting

Scenarios: "Space stages a file whose name is a suffix of a staged file", "Space stages when cwd is outside the repository", "Space unstages when cwd is outside the repository", "Space reports a staging failure".

- [x] 1.1 Failing tests in `tests/integration/file-tree/test_stage.lua`:
  - `file-tree: Space stages a file whose name is a suffix of a staged file`: repo with `a.lua` and `aa.lua`; modify both, stage `aa.lua`; after `<space>` on `a.lua`, `staged(dir)` contains both.
  - `file-tree: Space stages when cwd is outside the repository`: modified unstaged `a.lua`; after `<space>` on it, `staged(dir)` contains `a.lua`.
  - `file-tree: Space unstages when cwd is outside the repository`: modified and staged `a.lua`; after `<space>` on it, `staged(dir)` does not contain `a.lua`.
  - `file-tree: Space reports a staging failure`: modified unstaged `a.lua`; once the tree lists it, write an empty `<repo>/.git/index.lock`; after `<space>`, some recorded note has `level == vim.log.levels.ERROR` and `vim.startswith(msg, "Stage failed:")`.
  - `FILE=tests/integration/file-tree/test_stage.lua make test` fails on all four.
- [x] 1.2 In `lua/gleb/file_tree/init.lua` add LuaCATS-annotated `is_staged(path, cwd)`: `vim.system({ "git", "diff", "--cached", "--quiet", "--", path }, { cwd = cwd, text = true }):wait()`; exit 1 → `true`, 0 → `false`, any other exit → `nil, stderr`.
- [x] 1.3 Add LuaCATS-annotated `run_git(args, cwd, failure_prefix)`: `vim.system(args, { cwd = cwd, text = true }):wait()`; on non-zero exit `vim.notify(failure_prefix .. vim.trim(result.stderr), vim.log.levels.ERROR)`.
- [x] 1.4 Rewrite `git_toggle_stage(state)`: `cwd = state.path`, `path = node.path`; `is_staged` decides; staged → `run_git({ "git", "reset", "-q", "--", path }, cwd, "Unstage failed: ")`, unstaged → `run_git({ "git", "add", "--", path }, cwd, "Stage failed: ")`; `nil` from `is_staged` → `vim.notify("Stage failed: " .. vim.trim(stderr), vim.log.levels.ERROR)`; refresh `git_status` in every case. No `io.popen` / `vim.fn.system` / `fnamemodify` left in it. The four tests pass.

## 2. Existing staging scenarios keep working

Scenarios: "Space stages an unstaged file", "Space unstages a staged file" (existing `file-tree` spec, currently untested).

- [x] 2.1 Tests in `test_stage.lua` with cwd = repo root, `:Neotree git_status`:
  - `file-tree: Space stages an unstaged file`: modified unstaged `a.lua`; after `<space>`, `staged(dir)` contains `a.lua`.
  - `file-tree: Space unstages a staged file`: modified staged `a.lua`; after `<space>`, `staged(dir)` does not contain `a.lua`.
  - Regression guards for behaviour that already holds; check each one fails when its assertion is inverted, then restore it. Both pass on the task 1 code.

## 3. Nested path staging from a subdirectory cwd

Scenarios: "Space stages from a subdirectory cwd", "Space unstages from a subdirectory cwd".

- [x] 3.1 Tests in `test_stage.lua` with `sub/x.lua` committed, cwd = `<repo>/sub`, `:Neotree git_status`, cursor on the `x.lua` node:
  - `file-tree: Space stages from a subdirectory cwd`: modified unstaged `sub/x.lua`; after `<space>`, `staged(dir)` contains `sub/x.lua`.
  - `file-tree: Space unstages from a subdirectory cwd`: modified staged `sub/x.lua`; after `<space>`, `staged(dir)` does not contain `sub/x.lua`.
  - Regression guards like 2.1: each fails when its assertion is inverted. Both pass on the task 1 code.

## 4. Gate

- [x] 4.1 `make quick` green (lint, types, trace lists all eight scenarios as tested).
- [x] 4.2 `make check` green.
