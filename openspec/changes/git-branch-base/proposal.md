## Why

Kind: feature

Depends: fix-tree-folding

The user (2026-10-19) wants the branch's committed diff against its base in purple, a way to browse that
committed diff, and the pull request's review comments. Each of those needs one shared answer first: what
is this branch compared against? Today nothing in `lua/gleb/git/` knows more about a branch than its name
(gitsigns' `vim.b.gitsigns_head`): no pull request, no base branch, no merge-base.

This change adds that answer as a small async service with no UI. The purple gutter (`git-committed-signs`),
the Branch tab (`git-changes-tabs`) and the review threads (`pr-review-threads`) build on it.

## What Changes

- **New module `lua/gleb/git/base/`.** `rules.lua` holds the pure rules: remote host parsing, the
  default-branch choice, the no-base cases and pull request JSON parsing. `init.lua` holds the async
  resolver, the per-root cache, the git-dir watcher and the `User GlebGitBaseChanged` event. Its API:
  `resolve(path, callback)`, `get(root)`, `refresh(root, opts)`, `state` and `reset()` (design.md,
  Decision 1).
- **The base of a branch** (design.md, Decision 2):
  - The base is the open pull request's base branch, `origin/<baseRefName>`, when `gh pr view` reports an
    open pull request for the current branch.
  - Otherwise it is the remote default branch, `origin/<default>`. The default is the branch that
    `refs/remotes/origin/HEAD` points to, else `main`, else `master`.
  - The merge-base is `git merge-base <base> HEAD`. The committed layer of later changes is merge-base → HEAD.
- **No base** (and no `gh` call) on the default branch itself, on `main` or `master`, on a detached or unborn
  HEAD, outside a repository, without a remote default branch, and for unrelated histories.
- **Pull request lookup** runs `gh pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid`
  in the repository root:
  - with `GH_HOST` set to the `origin` URL's host (`pgw.dev` is GHES 3.22.1), and prompts and update checks off;
  - with a 10 s timeout;
  - only `OPEN` pull requests count.
  - A missing `gh`, an offline host, a failed login or a timeout falls back to the default branch silently.
    The last pull request found is kept until `gh` answers again.
- **Cache and refresh:**
  - Results are cached per repository root and recomputed only when the branch, HEAD or the base ref moves.
  - Triggers are `FocusGained`, a debounced libuv watch on the git dir (and the common dir of a linked
    worktree) and `refresh()`.
  - `gh` runs on the first resolve of a branch, after a branch switch, on a forced refresh, and on a trigger
    once the last answer is older than 5 minutes. At most one lookup runs per root at a time.
  - `User GlebGitBaseChanged` fires only when the result changes.
- **No network in tests.** Test children get `tests/fixtures/bin/gh` first on `PATH`. The stub says "no pull
  request" unless a case scripts it with `FAKE_GH_*` variables, and it logs its calls.
- **New fixture `prbranch`** in `tests/fixtures/build.sh`:
  - a `billing` repo on `feat/tax` with three commits over its merge-base with `origin/main`, two over its
    merge-base with `origin/release/1.4`, and one unstaged edit;
  - remote-tracking refs as a clone has them, with an `origin` URL on `pgw.dev` that is never contacted;
  - the manifest records the merge-bases and the committed lines (design.md, Fixture).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `git`: added "Branch base resolution", "Branch base exceptions", "Branch base pull request lookup" and
  "Branch base cache and refresh".

## Impact

- Code:
  - New: `lua/gleb/git/base/init.lua`, `lua/gleb/git/base/rules.lua`.
  - Unchanged: `lua/gleb/git/init.lua`. The module loads on first use, so startup does no git or `gh` work.
- Tests:
  - New: `tests/unit/git/test_base_rules.lua`, `tests/integration/git/test_base.lua`, `tests/fixtures/bin/gh`.
  - Changed: the `prbranch` fixture in `tests/fixtures/build.sh` (with its `fixtures.Manifest` keys in
    `tests/fixtures.lua`), and `M.isolate()` in `tests/helpers.lua`, which puts the stub first on `PATH`.
- Plugins: none added or removed. The `gh` CLI is an optional external tool: without it, the default branch
  is the base. octo.nvim was not chosen (user decision R2.7, quoted below).
- Core keymaps: none. No actions or keys change.
- Unchanged scenarios:
  - `git: Missing optional git plugins are tolerated` still holds: `require("gleb.git")` gains no require.
  - `git: Git commands are available after startup` still holds: no user command is added or removed.
  - `keymaps: Toggle wins over a pending changes refresh` still holds: the base's own `FocusGained` refresh
    opens and focuses no window and leaves the changes panel's refresh untouched.
- Out of scope:
  - Fetching. The base is the local remote-tracking ref as of the last `git fetch`, and the editor never
    fetches.
  - Remotes other than `origin`, and forks whose pull request targets an upstream remote.
  - Every UI: the gutter, the tabs and the threads come in the later changes.

## Decision (user, 2026-10-19)

- "Diff against base(for example pr diff, which is already comitted, in purple). And I somehow need to be able to see comitted diff. Also, I need to see pr comments."
- R2.2: "consider that this should still fallback to local if branch is "master" branch, since we are not working in context of pr."
- R2.7 build: our own on `gh api graphql` (not octo.nvim). R2.8 no PR: Branch tab vs origin/main, no Comments tab.
- R3.6 main/master: Local only.

## Agent decisions

- **Detached HEAD has no base.** There is no branch to look a pull request up for, and a rebase or bisect in
  progress should not flash a purple layer for a moment.
- **No `BufWritePost` trigger.** Writing a file moves neither HEAD nor any ref, so it cannot change the base.
  Buffer edits are mapped by `git-committed-signs` on its own.
- **Own git-dir watch.** It reuses no `file_tree/watch.lua` owner. Those owners are tree buffers with path
  sets, and the base must also watch roots that no tree shows.
- **A PR base missing locally.** When `origin/<baseRefName>` is not fetched but `baseRefOid` is present
  locally, the commit is used. When neither is there, the default branch is.
