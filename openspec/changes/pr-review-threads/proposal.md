## Why

Kind: feature
Depends: git-changes-tabs

The user wants the pull request's review comments in the editor: "Also, I need to see pr comments." The
Comments tab, the peeks and the thread window (`pr-comments-view`, `pr-thread-window`) all need the same
data first: the review threads of the current branch's open pull request, placed on the lines of the files
as they are now. Today nothing in the config talks to GitHub beyond `gh pr view` (`git-branch-base`), and
a thread's GitHub line points into the pull request's head commit, not into the edited working file.

This change adds that data layer with no UI beyond one Find Action entry and its notifications.

## What Changes

- **New module `lua/gleb/pr/`** (design.md, Decision 1):
  - `gh.lua`: an async `gh api graphql` client. Argument lists only, `GH_HOST` from the pull request,
    prompts off, a timeout. Reads only: the `ReviewThreads` and `ThreadComments` queries, 100 per page,
    following `pageInfo.endCursor`. It also classifies failures into one short message.
  - `threads.lua` (pure): parses the GraphQL nodes into a typed thread model, counts open threads, maps a
    line through `vim.text.diff` hunks and computes each thread's anchor.
  - `init.lua`: per-root cache under the pull request's `headRefOid`, `refresh`, `get`, `locate`, the
    refresh triggers and the `User GlebPrThreads` event.
  - `actions.lua`: `pr.refresh`.
- **Line mapping** (design.md, Decisions 3 and 4):
  - A thread anchors at the PR head and its line. An outdated thread (`line` null) anchors at its
    `originalCommit` and `originalLine`.
  - The anchor is mapped onto the buffer's current lines, unsaved edits included, through the hunks between
    `git show <oid>:<path>` and the buffer.
  - Left-side threads, file threads, threads whose commit is missing locally, and threads on a removed line
    are unmapped. They carry a reason, and `pr-comments-view` lists them in the Comments tab only.
- **Refresh** (design.md, Decision 5): on `pr.refresh`; when `changes.review` (Cmd+G) opens the closed
  panel; on `BufWritePost` in a pull-request root (debounced 1 s, at most once per 30 s); and when
  `GlebGitBaseChanged` reports a new head. One fetch runs per root at a time.
- **Errors** (design.md, Decision 6): a missing `gh`, a missing login or a network failure gives one WARN per
  root and kind. The cached threads stay, and the panel and signs keep working.
- **Fake `gh`**: `tests/fixtures/bin/gh` from `git-branch-base` gains `FAKE_GH_DIR` routing: one canned file
  per `gh` call, picked by subcommand and GraphQL operation. Canned `pr482` responses are added for the
  `billing-branch` fixture (design.md, Fixture).

## Capabilities

### New Capabilities
- `pr`: review threads of the current branch's pull request. Added: "Review thread fetch", "Review thread
  model", "Review thread line mapping", "Review thread anchors", "Review thread cache", "Review thread
  refresh", "Review thread errors", "PR refresh action".

### Modified Capabilities
- none

## Impact

- Code:
  - New: `lua/gleb/pr/{init,gh,threads,actions}.lua`.
  - Changed:
    - `lua/gleb/git/changes/init.lua`: the opening `changes.review` calls `require("gleb.pr").refresh(root)`
      when the base has a pull request;
    - `init.lua`: register `lua/gleb/pr/actions.lua` in the feature-action module list.
- Tests:
  - New:
    - unit `tests/unit/pr/test_threads.lua` (model, mapping, anchors) and `tests/unit/pr/test_gh.lua`
      (pagination with a stub runner, failure messages);
    - integration `tests/integration/pr/test_threads.lua` (fake `gh`, `billing-branch` copies);
    - fixture responses `tests/fixtures/gh/pr482.lua`.
  - Changed: `tests/fixtures/bin/gh` (`FAKE_GH_DIR`).
- Plugins: none added, removed or upgraded. The user chose our own client over octo.nvim (decision R2.7).
  The `gh` CLI is an optional external tool.
- Core keymaps: none. `pr.refresh` is unbound.
- Unchanged scenarios:
  - `file-tree: Requirement: Project tree refresh and operation keys` still holds: `pr.refresh` is a distinct action and does not change `file_tree.refresh` or its configured mappings.
  - `file-tree: Requirement: Project tree refresh isolation` still holds: PR refreshes do not invoke `file_tree.refresh` or modify any project-tree view state.
  - `file-tree: Project tree coalesces a save burst` still holds: the PR write hook is a separate augroup and does not add a project-tree draw or git-status request.
  - `git: Changes panel review replaces the dashboard` still holds: the background fetch starts only after the panel has opened and does not change its window replacement.
  - `git: Branch base passes the remote host to gh` still holds: `gh pr view` keeps its existing argv, `GH_HOST` and log entry; the new GraphQL routing is a separate fake-`gh` mode.
  - `git: Branch base clears the pull request when none is found` still holds: clearing the base PR still emits `GlebGitBaseChanged`; the thread listener only drops its cache and runs no GraphQL without a PR.
  - `git: Branch base is cached` still holds: thread caching consumes the resolved base and does not alter base lookup or its event count.
  - `git: Branch base refreshes after a commit` still holds: the thread listener observes `GlebGitBaseChanged` without changing HEAD discovery, merge-base state or base `gh` calls.
  - `git: Branch base refreshes after a checkout` still holds: the thread listener only clears its own cache when the base cache becomes nil.
  - `git: Branch base keeps the last pull request when gh fails` still holds: thread refresh failure handling does not replace the branch-base cache or alter its `gh pr view` failure path.
  - `git: Requirement: Committed signs follow the buffer` still holds: PR locations use a separate module and namespace, and only observe the same base-change event.
  - `git: Local tab matches the approved render` still holds: fetching threads draws no UI and changes no panel text, highlights or layout.
  - `git: Cmd+G cycles Local, Branch, then closes` still holds: only opening a closed panel triggers the asynchronous fetch; tab order, focus, diffs and close behavior are untouched.
  - `git: Async Branch activation reviews a Branch row` still holds: a thread fetch neither selects a row nor requests a panel diff.
  - `git: First review opens Branch when nothing is uncommitted` still holds: the asynchronous fetch does not participate in first-tab selection or panel closing.
  - `git: Review on the default branch opens only Local` still holds: the default branch has no pull request, so no thread fetch runs and the tab cycle is unchanged.
  - `git: Review from the diff window advances the tab` still holds: the panel is already open, so this invocation does not trigger a fetch and keeps the existing focus transition.
  - `git: Branch tab matches the approved render` still holds: the PR 482 fetch is data-only and draws no thread content in this change.
  - `git: Review starts the cycle again after a close` still holds: reopening still selects Local; the background refresh does not restore or select a tab.
  - `git: Changes panel review shows the current file's diff` still holds: the fetch runs in the background after the panel opens and changes no row, focus or diff.
  - `git: Changes panel review without a changed current file` still holds: same reason.
  - `git: Changes panel with the diff view matches the approved render` still holds: the `billing` fixture has no pull request, so nothing is fetched or drawn.
  - `git: Changes panel ]f steps through every changed file` still holds: the `dirty` fixture has no pull request and `]f` is untouched.
  - `git: Requirement: Changes panel outside a repository` still holds: a fetch is only triggered after the panel opened on a resolved root.
  - `git: Changes panel entry points are actions` still holds: `changes.review` keeps its id, title and category.
  - `git: Requirement: Changes panel refresh` still holds: the thread refresh on `BufWritePost` is a separate augroup and changes no panel row.
  - `git: Cmd+G opens the changes review of a dirty repo` still holds: the `dirty` fixture has no pull request, so no `gh` call is made.
  - `keymaps: Requirement: Changes review entry point` still holds: `<A-g>` still maps to `changes.review`.
  - `session: Requirement: Save on write and exit` still holds: the new `BufWritePost` autocmd is in its own `gleb_pr` augroup and does not touch session saving.
  - `statusline: refresh timer stops when idle` still holds: PR refreshes do not change the LSP progress timer or call `lualine.refresh`.
  - `statusline: refresh timer stops on exit` still holds: the PR augroup does not change the LSP progress timer's `VimLeavePre` cleanup.
  - `diff: A too big comparison falls back to xdiff` still holds: thread mapping calls `vim.text.diff` on its own inputs; the diff engine is unchanged.
  - `diff: Requirement: Diff view hunk staging` still holds: no staging code changes.
  - `actions: Every configured action is registered` still holds: `pr.refresh` is registered and has no entry in the shortcut file.
- Out of scope:
  - Any UI: the Comments tab, peeks, statusline and thread window (`pr-comments-view`, `pr-thread-window`).
  - Writing: replies, resolve and new threads (`pr-thread-window` adds replies and resolve).
  - Pending (unsubmitted) reviews, suggestions and reactions.
  - Pull requests of forks and remotes other than `origin` (as in `git-branch-base`).
  - Fetching commits that are missing locally: such threads stay unmapped.

## Decision (user, 2026-10-19)

- Request: "Also, I need to see pr comments."
- R2.7 build: our own on `gh api graphql` (not octo.nvim).
- R2.8: without a pull request there is no Comments tab, so no threads are fetched.

## Agent decisions

- **Anchors use GitHub's own coordinates.** `line` is relative to the pull request head, and `originalLine` to
  `originalCommit` (verified on pgw.dev, GHES 3.22.1: `line` is null when a thread is outdated). Mapping from
  that exact file content is exact. Guessing from `diffHunk` text is not.
- **A line inside a changed block keeps its offset.** It is not dropped, as IntelliJ's
  `transferLineToAfter` does. A reviewer's thread on a line the author has since edited is still worth showing
  there. Only a removed line is unmapped.
- **Write refresh is throttled** to once per 30 s per root. Rate limiting is disabled on pgw.dev, but a save
  loop (format on save, autosave) should not turn into a request loop.
- **One WARN per failure kind.** Background fetches follow rule 8.4 and stay silent after the first notice;
  the explicit `pr.refresh` always reports.
- **Queries are single-line strings** with a named operation (`query ReviewThreads`). The fake `gh` logs one
  line per call and routes by the name, so tests stay readable.

## Decision (user, 2026-10-20)

- Don't guess the GitHub API: the agent may call the real API on this repo's own PRs (GlebBeloded/nvim.config, through
  `gh`) to learn the exact request and response shapes, then record those responses as fixtures and test against the
  mocked responses. Tests never call the network.
