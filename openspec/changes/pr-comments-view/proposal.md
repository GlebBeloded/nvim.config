## Why

Kind: feature
Depends: pr-review-threads

`pr-review-threads` fetches the pull request's review threads and maps them onto the working files, but
nothing shows them. The user wants them where the code is: a Comments tab in the changes panel ("maybe
comments tab aswell would be good"), the threads peeking in the editor, resolved ones folded away, and the PR
number with the open-thread count in the bottom bar ("please make sure that this: #482 is in our bottom
bar").

## What Changes

- **Comments tab** (design.md, Decisions 1–3). The changes panel gets a third tab, `Comments <open>` (yellow,
  `ChangesTabComments`). It is appended to the `git-changes-tabs` tab list only while the branch has an open
  pull request. `changes.review` (Cmd+G) then cycles Local → Branch → Comments → close.
  - Rows: the Branch tab's header, `3 open · 1 resolved`, then the threads grouped by file in the shared tree
    (`lua/gleb/ui/tree/`, so the panel's fold keys work).
  - A thread row is an icon, `:<line>`, the author and the first comment cut to fit.
  - Open threads come first and resolved ones after, dimmed. Outdated threads carry an orange `outdated` tag.
  - `Loading…` shows before the first fetch, and the failure message after a failed one.
- **Selection and Enter.**
  - Moving onto a thread shows its file at the line in the editor window, and focus stays in the panel. The
    panel's diff view closes while the Comments tab is active.
  - An unmapped thread shows its `diffHunk` instead.
  - Enter (`changes.open`) opens the file at the line and focuses it.
- **Peeks in the editor and the diff view** (design.md, Decisions 4–6):
  - Each open thread is one virtual line under its line: `╰─ <icon> maria.k Should a nil rate… +1 reply`.
  - It expands into the whole thread, in a box, while the cursor is on that line or the thread is selected
    in the Comments tab.
  - A resolved thread is one grey line, `╰─ ✓ Resolved · ivan.p: Should ID stay a string? The…`. Outdated
    threads are not drawn in code.
  - The diff view draws the same peeks on its right side and pads the left side, so rows stay aligned.
- **Smart cut** (design.md, Decision 5). Only the first line of a comment is shown. If it is still too wide
  for the window's text width minus the indent and the rest of the row, it is cut at the last word that fits,
  then `…`.
- **Actions without keys** (Find Action): `pr.next_thread` and `pr.prev_thread` jump between open threads in
  the buffer and on to the next file. `changes.show_comments` opens the Comments tab.
- **Statusline** (design.md, Decision 7): after the branch, ` #482` in purple and, when there are open
  threads, ` 3` in yellow. It is hidden without a pull request and reads caches only.
- **Highlight groups** from the palette: `PrPeek`, `PrPeekAuthor`, `PrPeekIcon`, `PrPeekMeta`,
  `PrThreadResolved`, `PrThreadOutdated`, `PrStatuslineNumber`, `PrStatuslineThreads`, `ChangesTabComments`.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `pr`: added "Comments tab", "Comments tab rows", "Comments tab selection", "Comments tab Enter", "Thread
  peeks", "Peek text cut", "Diff view peeks", "Thread navigation" and "Review highlight colours".
- `statusline`: added "Pull request component".

## Impact

- Code:
  - New: `lua/gleb/pr/{comments_tab,peek,statusline,highlights}.lua`.
  - Changed:
    - `lua/gleb/pr/{init,actions}.lua` (the new actions, and the peek and tab redraws on `GlebPrThreads`);
    - `lua/gleb/git/changes/tabs.lua` (the `comments` descriptor);
    - `lua/gleb/git/changes/{view,init}.lua` (a tab can own the editor window instead of the diff view);
    - `lua/gleb/diff/view/{init,render}.lua` (a decoration provider for the right side, with left padding);
    - `lua/gleb/statusline/lualine.lua` (the component in section b, after the branch).
- Tests:
  - unit `tests/unit/pr/test_peek.lua` (cut, peek lines, row text);
  - integration `tests/integration/pr/test_comments_tab.lua`, `tests/integration/pr/test_peek.lua`,
    `tests/integration/statusline/test_pr.lua`;
  - screen `tests/screen/pr/test_comments.lua`, `tests/screen/statusline/test_pr.lua`.
- Plugins: none added, removed or upgraded. octo.nvim shows review threads in its own review tab and buffers,
  not in the working file or this panel; the user chose our own build (R2.7).
- Core keymaps: none. Cmd+G keeps `changes.review`, whose cycle gains the Comments step when a pull request
  exists. The new actions are unbound.
- Unchanged scenarios:
  - `git: Changes panel mappings come from the shortcut file` still holds: the Comments tab adds no panel mapping; `<CR>` stays `changes.open`.
  - `git: Changes panel entry points are actions` still holds: `changes.toggle` and `changes.review` keep their titles and category.
  - `git: Changes panel review shows the current file's diff` still holds: the first `changes.review` still opens the Local tab with its diff.
  - `git: Changes panel review without a changed current file` still holds: same first-press rule.
  - `git: Cmd+G opens the changes review of a dirty repo` and `git: Cmd+G with the project tree open replaces it` still hold: the `dirty` fixture has no pull request, so there is no Comments tab.
  - `git: Changes panel with the diff view matches the approved render` and `git: Changes panel matches the approved render` still hold: the `billing` fixture is on `main` with no pull request, so no peek, tab or statusline part is drawn.
  - `git: Changes panel Enter opens the file` still holds: `changes.open` on Local rows is unchanged; only Comments rows get the thread behaviour.
  - `statusline: statusline matches reference screenshot` and `statusline: insert mode accent matches reference screenshot` still hold: their Lua file is outside any pull request, so the component draws nothing.
  - `statusline: Requirement: Global statusline layout` still holds: section b keeps the branch and diff components; the new component sits between them and is empty without a pull request.
  - `git: Requirement: Changes panel outside a repository` still holds: no Comments tab exists without a resolved root and pull request.
  - `git: Changes panel ]f steps through every changed file` still holds: the `dirty` fixture has no pull request and `]f` only walks diff tabs.
  - `keymaps: Requirement: Changes review entry point` still holds: `<A-g>` still maps to `changes.review`.
- Out of scope:
  - Replying, resolving and opening a thread in its own window (`pr-thread-window`).
  - Starting new threads, suggestions, reactions, review approval state in the statusline (user picked
    "number and open threads").
  - Peeks for `LEFT`-side threads in the diff view's left pane: they are listed in the Comments tab with
    their hunk.

## Decision (user, 2026-10-19)

- Request: "Also, I need to see pr comments."
- P3 panel: "Also maybe comments tab aswell would be good." R2.1 cycle: Local → Branch → Comments → close.
- R2.2: "please make sure that this:  #482 is in our bottom bar". R3.5 statusline: PR number + open-thread
  count (approved mock `r3_status_threads`).
- R2.4 threads: peek in the editor (approved mock `r2_comments_peek`).
- R2.5 resolved: folded to one grey line — "make sure to cut off long messages by some smart strategy (like
  first line only). If its too long, cut by words".
- Latest: "Just make next thread action, without shortcut. Also make sure there are [actions] for Threads and
  Branch Commits" → `pr.next_thread` / `pr.prev_thread` unbound; `changes.show_comments` opens the Comments
  tab.

## Agent decisions

- **Peeks start at the commented line's indent**, so they read as part of the code block; the cut width is the
  window's text width minus that indent and the rest of the row. The approved mock started them at column 0.
- **The expanded thread is a box of virtual lines without hints.** The approved inline mock carried
  `reply r · resolve R` on its bottom border, which rule 8.9 forbids and which `pr-thread-window` moves into
  the thread window.
- **Expansion follows the current window only.** A peek expands when its window is current with the cursor on
  the line, or when the thread is selected in the current Comments tab, so the thread window of the next change
  opens over a collapsed peek.
- **The statusline hides the thread count at 0** and until the threads are first fetched; the number shows as
  soon as the base knows the pull request.
- **Counts are open threads**: the tab label, the folder and file counts and the statusline all count
  unresolved threads, outdated ones included.
- **Navigation skips resolved and outdated threads**: it is for working through what is still open.
- **One fixture state for every render**: the four `pr482` threads. So the peek render also shows the resolved
  `:11` line and the `:13` peek, which the approved mock (one thread) did not.
- **`No pull request for <branch>` is a WARN**, like `git-changes-tabs`' `No branch changes on <branch>`.

## Decision (user, 2026-10-20)

- Don't guess the GitHub API: the agent may call the real API on this repo's own PRs (GlebBeloded/nvim.config, through
  `gh`) to learn the exact request and response shapes, then record those responses as fixtures and test against the
  mocked responses. Tests never call the network.
