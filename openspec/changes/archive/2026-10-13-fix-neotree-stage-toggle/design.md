## Context
Root cause (see proposal.md - Why): `git_toggle_stage` (`lua/gleb/file_tree/init.lua:57-77`) reads `git diff --cached --name-only` through `io.popen` in Neovim's cwd and does a plain substring `find` for `fnamemodify(node.path, ":.")`.
- Suffix bug: the name list is one string, so `a.lua` is found inside `aa.lua`; the file is treated as staged and `git reset` runs on a file that was never staged (a no-op), so `<space>` does nothing.
- cwd bug: git prints root-relative paths (`sub/x.lua`) while the needle is cwd-relative. For a file under cwd the substring search hits by accident (`x.lua` in `sub/x.lua`); for a file outside cwd `:.` leaves the path absolute, so it is never found. With cwd outside the repository (tree opened with `dir=`), `git diff --cached` and `git add` run in a non-repo and fail silently: a staged file reads as unstaged and `<space>` can neither stage nor unstage.
- `git add` / `git reset` go through `vim.fn.system` shell strings with no exit check, so a locked index fails silently (rule 6.4).

`node.path` is absolute; neo-tree's `state.path` is the directory the `git_status` source was opened for (inside the repository).

## Goals / Non-Goals
Goals: the staged/unstaged decision comes from git for the exact path, independent of cwd; failures are shown as ERROR notifications.
Non-goals: no change to the tree render, mappings, or the asynchronous behaviour (the calls stay synchronous, as today).

## Decisions
- Proposed A (picked): ask git per path. `git diff --cached --quiet -- <node.path>` via `vim.system({...}, { cwd = state.path }):wait()`; exit 1 means staged, 0 unstaged. Git resolves the absolute pathspec against the repo root itself, so no root-relative path is computed, and a directory node is "staged if any file under it is staged", which keeps the out-of-scope directory behaviour unchanged. Any other exit is a failure and is reported like a stage failure.
- Proposed B: `git rev-parse --show-toplevel`, make `node.path` root-relative and compare against whole lines of `--name-only`. Rejected: two commands, path normalisation (symlinks such as macOS `/var` → `/private/var` break `vim.fs.relpath`), and directory nodes would need prefix matching.
- Commands: `{ "git", "add", "--", path }` and `{ "git", "reset", "-q", "--", path }` with `vim.system` and `cwd = state.path`. On non-zero exit: `vim.notify("Stage failed: " .. vim.trim(stderr), ERROR)` / `"Unstage failed: …"`. `git_status` is refreshed in every case.
- Small named functions (rule: no long anonymous functions): `is_staged(path, cwd)`, `run_git(args, cwd, failure_prefix)`, and `git_toggle_stage` composing them.
- No visible UI change: the tree render is unchanged and the failure goes through `vim.notify` (rule 8.1), asserted as a notification, so no renders.

## Risks / Trade-offs
- [`git diff --cached` on an unborn branch compares against the empty tree] → still correct: newly added files show as staged.
- [index.lock present: `git diff --cached --quiet` reads the index without taking the lock] → the decision still succeeds and the following `git add` fails with git's `Unable to create '…/index.lock'` message, which is what the failure scenario asserts.
