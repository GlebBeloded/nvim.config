# pr Specification

## Purpose
Pull request review inside the editor: the review threads of the current branch's open pull request, fetched with `gh api graphql`, mapped onto the files as they are now, and shown and answered without leaving Neovim. `lua/gleb/pr/` owns the GraphQL client, the thread model, the line mapping, the cache, and the views that later changes add.

## Requirements

### Requirement: Review thread fetch
When `gleb.git.base` reports an open pull request for a root, `require("gleb.pr").refresh(root)` SHALL fetch its review threads with `gh api graphql` (an argument list, `GH_HOST` set to the PR host): 100 threads per page, following `pageInfo.endCursor` while `hasNextPage` is true, then the remaining comments of any thread with more. Without a pull request it SHALL run no `gh`.

#### Scenario: PR threads are fetched with gh api graphql
- **WHEN** a fresh copy of the `billing-branch` fixture has the fake `gh` serving the `pr482` responses, `require("gleb.pr").refresh(root)` runs and `User GlebPrThreads` fires
- **THEN** the fake `gh` log has exactly one `api graphql` line, with host `pgw.dev`, `-f owner=finteqhub`, `-f name=billing`, `-F number=482` and `query ReviewThreads`, and `require("gleb.pr").get(root).threads` holds `PRRT_t1`, `PRRT_t2`, `PRRT_t3`, `PRRT_t4` in that order

#### Scenario: PR thread pages follow the end cursor
- **WHEN** `require("gleb.pr.gh").fetch_threads(pr, run)` runs with a stub `run` that answers the first call with threads `PRRT_t1`, `PRRT_t2`, `hasNextPage` true and `endCursor` `c2`, and the second with `PRRT_t3`, `PRRT_t4` and `hasNextPage` false
- **THEN** `run` was called twice, only the second argument list holds `-f` `cursor=c2`, and the callback gets the four threads in order

#### Scenario: Long PR threads load every comment
- **WHEN** the stub answers the threads page with `PRRT_t1` holding one comment, `comments.pageInfo.hasNextPage` true and `endCursor` `k1`, and a `query ThreadComments` call with `-f id=PRRT_t1` and `-f cursor=k1` with the second comment
- **THEN** the callback's `PRRT_t1` holds both comments in order and `run` was called twice

#### Scenario: No pull request runs no GraphQL
- **WHEN** the fake `gh` reports no pull request for `feat/tax` and `require("gleb.pr").refresh(root)` runs on a fresh copy of the `billing-branch` fixture
- **THEN** the fake `gh` log holds no `api graphql` line and `require("gleb.pr").get(root)` is nil

### Requirement: Review thread model
`require("gleb.pr.threads").parse(nodes)` SHALL return one thread per node, in order, with `id`, `path`, `side`, `line`, `start_line`, `original_line`, `original_commit` (the first comment's), `resolved`, `outdated`, `subject` (`line` or `file`), `resolved_by`, `can_reply`, `can_resolve`, `can_unresolve` and `comments` (`id`, `author` login or `ghost`, `body`, `created_at`, `url`, `diff_hunk`, `reply_to`). `open_count` SHALL count the unresolved threads.

#### Scenario: PR thread model keeps the GraphQL fields
- **WHEN** `parse` runs on the `pr482` threads page
- **THEN** `PRRT_t1` has path `internal/billing/invoice.go`, side `RIGHT`, line 22, `resolved` and `outdated` false and two comments by `maria.k` and `gleb-beloded`, the second replying to the first; `PRRT_t3` has line nil, `original_line` 18, `original_commit` the fixture's `add tax.go` commit and `outdated` true; `PRRT_t4` is resolved by `gleb-beloded`

#### Scenario: PR thread author falls back to ghost
- **WHEN** `parse` runs on a node whose only comment has `author` null
- **THEN** that comment's `author` is `ghost`

#### Scenario: Open PR threads are counted
- **WHEN** `require("gleb.pr.threads").open_count` runs on the parsed `pr482` threads
- **THEN** it returns 3

### Requirement: Review thread line mapping
`require("gleb.pr.threads").map_line(from, to, line)` SHALL map a 1-based line of the `from` lines onto the `to` lines through the `vim.text.diff` hunks between them: a line outside every hunk shifts by the lines added and removed above it; a line inside a replaced block maps to the new block's line at the same offset, capped at its last line; a removed line maps to nil.

#### Scenario: Thread line shifts below inserted lines
- **WHEN** `map_line({ "a", "b", "c", "d" }, { "a", "x", "y", "b", "c", "d" }, line)` runs for lines 1 to 4
- **THEN** it returns 1, 4, 5 and 6

#### Scenario: Thread line inside a replaced block keeps its offset
- **WHEN** `map_line({ "a", "b", "c", "d", "e" }, { "a", "B", "C", "e" }, line)` runs for lines 1 to 5
- **THEN** it returns 1, 2, 3, 3 and 4

#### Scenario: Thread line on a removed line is unmapped
- **WHEN** `map_line({ "a", "b", "c" }, { "a", "c" }, line)` runs for lines 1 to 3
- **THEN** it returns 1, nil and 2

### Requirement: Review thread anchors
A thread SHALL anchor at `(headRefOid, line)` when it has a line, and at `(original_commit, original_line)` when it is outdated; a `LEFT`-side or file thread SHALL have no anchor. `require("gleb.pr").locate(buf)` SHALL map each thread of the buffer's file onto the buffer's current lines, unsaved edits included, from `git show <oid>:<path>`, and return the unmapped ones with a reason: `left side`, `file`, `missing commit` or `removed`.

#### Scenario: PR threads map onto the working file
- **WHEN** `internal/billing/invoice.go` of the `billing-branch` fixture is edited after a `pr482` refresh and `locate(0)` runs
- **THEN** `PRRT_t1` maps to line 22, `PRRT_t2` to 13 and `PRRT_t4` to 11, nothing is unmapped, and no `PRRT_t3` entry is returned

#### Scenario: PR threads follow unsaved edits
- **WHEN** two lines are inserted above line 1 of that buffer without writing it and `locate(0)` runs
- **THEN** `PRRT_t1` maps to line 24 and `PRRT_t2` to 15

#### Scenario: A PR thread on a removed line is unmapped
- **WHEN** line 22 of that buffer is deleted and `locate(0)` runs
- **THEN** `PRRT_t1` is unmapped with reason `removed` and `PRRT_t2` still maps to 13

#### Scenario: An outdated PR thread anchors at its original commit
- **WHEN** `internal/billing/tax.go` is edited after a `pr482` refresh and `locate(0)` runs
- **THEN** `PRRT_t3` maps to line 18 and is marked outdated

#### Scenario: A PR thread at a missing commit is unmapped
- **WHEN** the served `PRRT_t3` names an `originalCommit` that is not in the repository and `locate` runs on `tax.go`
- **THEN** `PRRT_t3` is unmapped with reason `missing commit` and no notification is emitted

#### Scenario: Left-side and file PR threads are unmapped
- **WHEN** the served threads add one with `diffSide` `LEFT` and one with `subjectType` `FILE` on `invoice.go`, and `locate` runs on it
- **THEN** they are unmapped with reasons `left side` and `file`

### Requirement: Review thread cache
Threads SHALL be cached per root under the pull request's `headRefOid`; `get(root)` SHALL answer from the cache and run nothing. A `GlebGitBaseChanged` event with a new `headRefOid` SHALL drop the cache and fetch again. `git show` contents SHALL be cached per `oid:path`. Each successful fetch SHALL fire `User GlebPrThreads` with `data.root`.

#### Scenario: PR threads are cached per head
- **WHEN** after a `pr482` refresh `get(root)` is called twice and `locate` runs twice on `invoice.go`
- **THEN** no new `gh` log line is written and `git show` of `invoice.go` at the head runs once

#### Scenario: A new PR head fetches the threads again
- **WHEN** after a `pr482` refresh the fake `gh` reports a new `headRefOid` and `require("gleb.git.base").refresh(root, { force = true })` runs
- **THEN** one more `query ReviewThreads` line is logged and `get(root).head` is the new oid

#### Scenario: A new PR head during forced refresh fetches again
- **WHEN** `pr.refresh` runs with `FAKE_GH_SLEEP`, then the fake `gh` reports a new `headRefOid` and `require("gleb.git.base").refresh(root, { force = true })` runs before the fetch completes
- **THEN** the stale result is dropped, one more `query ReviewThreads` line is logged, `get(root).head` is the new oid, and `PR #482: 3 open threads` is notified at INFO

#### Scenario: PR thread updates fire an event
- **WHEN** a `User GlebPrThreads` autocmd is registered and a `pr482` refresh completes
- **THEN** it ran once with `data.root` equal to the normalized fixture root

### Requirement: Review thread refresh
Threads SHALL be fetched on `pr.refresh`, when `changes.review` opens a closed changes panel, and on `BufWritePost` of a file under a root with a pull request (debounced 1000 ms, at most once per 30 s). One fetch SHALL run per root at a time; a trigger during it SHALL queue one more; a stale result SHALL be dropped. `pr.refresh` SHALL notify `PR #<n>: <k> open threads` at INFO, or `No pull request for <branch>` at WARN.

#### Scenario: pr.refresh fetches the threads again
- **WHEN** the `pr.refresh` action runs twice on the `billing-branch` fixture with `pr482` served, each waiting for `GlebPrThreads`
- **THEN** two `query ReviewThreads` lines are logged and `PR #482: 3 open threads` is notified at INFO twice

#### Scenario: Opening the review panel fetches the threads
- **WHEN** `changes.review` runs with the panel closed on the `billing-branch` fixture with `pr482` served, then runs again
- **THEN** one `query ReviewThreads` line is logged after the first run and none after the second

#### Scenario: Writing a file fetches the threads once
- **WHEN** after a `pr482` refresh `invoice.go` is written with `:write`, 1500 ms pass, then it is written again
- **THEN** exactly one more `query ReviewThreads` line is logged within 3000 ms of the first write

#### Scenario: Writing a file fetches threads before any manual refresh
- **WHEN** `invoice.go` is written in a fresh configured child with `pr482` served and no prior PR refresh
- **THEN** one `query ReviewThreads` line is logged within 3000 ms

#### Scenario: A trigger during a fetch queues one more
- **WHEN** `FAKE_GH_SLEEP` is 1 and `require("gleb.pr").refresh(root)` runs three times within 100 ms
- **THEN** exactly two `query ReviewThreads` lines are logged

#### Scenario: pr.refresh without a pull request
- **WHEN** the fake `gh` reports no pull request and the `pr.refresh` action runs on the `billing-branch` fixture
- **THEN** `No pull request for feat/tax` is notified at WARN and no `api graphql` line is logged

### Requirement: Review thread errors
A failed fetch SHALL keep the cached threads and notify at WARN once per root and failure: `PR comments unavailable: gh not found`, `… gh is not authenticated for <host>` (stderr naming `gh auth login`, or HTTP 401), else `… <first stderr line or GraphQL error message>`. Repeats SHALL be silent until a fetch succeeds; `pr.refresh` SHALL always notify. The changes panel and signs SHALL work as before.

#### Scenario: PR fetch failures are classified
- **WHEN** `require("gleb.pr.gh").failure(result, host)` runs for a missing `gh`; exit 4 with `To get started with GitHub CLI, please run:  gh auth login`; exit 1 with `HTTP 401: Bad credentials (https://pgw.dev/api/graphql)`; exit 1 with `error connecting to pgw.dev` and a second line; exit 0 with `{"errors":[{"message":"Could not resolve to a PullRequest with the number of 482."}]}`
- **THEN** the messages are `PR comments unavailable: gh not found`, `PR comments unavailable: gh is not authenticated for pgw.dev` twice, `PR comments unavailable: error connecting to pgw.dev` and `PR comments unavailable: Could not resolve to a PullRequest with the number of 482.`

#### Scenario: A missing gh fetch warns and clears in-flight refresh
- **WHEN** a cached `pr482` root loses `gh` from `PATH` and `require("gleb.pr").refresh(root)` runs
- **THEN** `PR comments unavailable: gh not found` is notified at WARN, the root has no in-flight refresh, and a later refresh completes after `gh` returns

#### Scenario: A failed PR fetch warns once and keeps the threads
- **WHEN** after a `pr482` refresh the fake `gh` answers `query ReviewThreads` with exit 1 and `error connecting to pgw.dev`, and `require("gleb.pr").refresh(root)` runs twice
- **THEN** `PR comments unavailable: error connecting to pgw.dev` is notified at WARN once, `get(root).threads` still holds four threads, and `changes.toggle` opens the panel with the `Changes 2 files` row

#### Scenario: pr.refresh always reports a failure
- **WHEN** the fake `gh` keeps failing that way and the `pr.refresh` action runs twice
- **THEN** the WARN is notified twice

### Requirement: PR refresh action
`pr.refresh` SHALL be a catalog action titled `Refresh Pull Request Comments` in category `Git | Pull Request`, with no shortcut in `settings/keymap.json`, so it runs from Find Action.

#### Scenario: pr.refresh is an unbound Find Action entry
- **WHEN** the action catalog and `settings/keymap.json` are read after startup
- **THEN** the catalog has `pr.refresh` titled `Refresh Pull Request Comments` in `Git | Pull Request` and the shortcut file has no `pr.refresh` key

### Requirement: Thread mutation requests
`require("gleb.pr.gh").reply(review, thread_id, body, run?, callback)` SHALL run `mutation AddReply` (`addPullRequestReviewThreadReply`). `set_resolved(review, thread_id, resolved, run?, callback)` SHALL run `mutation ResolveThread` (`resolveReviewThread`) or `mutation UnresolveThread` (`unresolveReviewThread`). Both SHALL call back `(true)` on success or `(false, message)` with `gh.failure`'s message without its `PR comments unavailable: ` prefix.

#### Scenario: Resolve requests name the thread
- **WHEN** `set_resolved(pr, "PRRT_t1", true, run)` and `set_resolved(pr, "PRRT_t4", false, run)` run with a stub `run` answering the recorded responses
- **THEN** the first argument list holds `query=mutation ResolveThread…` and `id=PRRT_t1`, the second `query=mutation UnresolveThread…` and `id=PRRT_t4`, and both callbacks get `true`

#### Scenario: A failed mutation returns its message
- **WHEN** the stub answers `reply` with exit 1 and stderr `HTTP 502: Bad Gateway`, then `set_resolved` with exit 0 and the recorded `errors` response `Resource not accessible by integration`
- **THEN** the callbacks get `false, "HTTP 502: Bad Gateway"` and `false, "Resource not accessible by integration"`

### Requirement: Thread mutation transport
Thread mutations SHALL run `gh api graphql` as an argument list with no shell, using the query request's environment and timeout. Each SHALL pass `-f query=<one-line document>` and `-f id=<thread id>`; replies SHALL also pass `-f body=<body>` so every body character reaches GitHub unchanged.

#### Scenario: A reply request passes the body as one argument
- **WHEN** `reply(pr, "PRRT_t1", body, run)` runs with a stub `run` and the body `it's "fine" $(touch /tmp/pwned) @notes.md`
- **THEN** `run` gets one argument list starting `gh api graphql`, holding `-f` `query=mutation AddReply…`, `-f` `id=PRRT_t1` and `-f` `body=it's "fine" $(touch /tmp/pwned) @notes.md` as single elements, with `GH_HOST=pgw.dev` in its env

### Requirement: Comments tab
When `gleb.git.base` reports an open pull request, the changes panel SHALL append a `Comments <open threads>` tab after Branch (`ChangesTabComments` when active), so `changes.review` cycles Local, Branch, Comments, then closes. Without a pull request there SHALL be no Comments tab. `changes.show_comments` ("Show Pull Request Comments", `View | Tool Windows`, no key) SHALL open or focus the panel on it, else warn `No pull request for <branch>`.

#### Scenario: Comments tab follows Branch with a pull request
- **WHEN** `internal/billing/invoice.go` of a fresh copy of the `billing-branch` fixture is edited with the `pr482` responses served and the `changes.toggle` action runs
- **THEN** the panel's winbar renders as `  Local 3   Branch 4   Comments 3 `, with `Comments 3` in `ChangesTabInactive`

#### Scenario: Cmd+G cycles Local, Branch, Comments, then closes
- **WHEN** that file is edited with `pr482` served and the `changes.review` action runs four times, waiting for the panel after each of the first three
- **THEN** the active tab is Local, then Branch, then Comments with the `gleb-changes` window current and no `gleb-diff` window, and after the fourth run no `gleb-changes` window remains

#### Scenario: Show Pull Request Comments opens the Comments tab
- **WHEN** that file is edited with `pr482` served, no panel is open and the `changes.show_comments` action runs
- **THEN** the `gleb-changes` window is current, the Comments tab is active and the action has no `settings/keymap.json` assignment

#### Scenario: Show Pull Request Comments without a pull request
- **WHEN** the fake `gh` reports no pull request for `feat/tax` and the `changes.show_comments` action runs
- **THEN** `No pull request for feat/tax` is notified at WARN and no `gleb-changes` window is opened

### Requirement: Comments tab rows
The tab SHALL show the Branch tab's header, `<n> open · <m> resolved`, an empty line, then a `ui/tree` tree: compacted directories and files (names `ChangesCommittedFile`, open count `ChangesCount`), and per thread an icon, `:<line>` (`line`, else `originalLine`; `file` for a file thread), the author and the first comment cut to fit, `outdated` right-aligned. Open threads come first, then resolved, each by line. Before the first fetch it SHALL show `Loading…`, after a failure its message.

#### Scenario: Comments tab lists the threads by file
- **WHEN** the Comments tab of the `billing-branch` fixture is shown with `pr482` served
- **THEN** the panel rows, with icons and padding removed, are in order `#482 feat/tax → main`, `3 open · 1 resolved`, ``, `internal/billing 3`, `invoice.go 2`, `:13 ivan.p Rate or *Rate…`, `:22 maria.k Should a nil…`, `:11 ivan.p Should ID stay…`, `tax.go 1`, `:18 maria.k Round… outdated`

#### Scenario: Comments tab row colours
- **WHEN** the Comments tab of the `billing-branch` fixture is shown with `pr482` served
- **THEN** on the `:22` row the icon is in `PrPeekIcon`, `:22` in `PrPeekMeta`, `maria.k` in `PrPeekAuthor` and the text in `PrPeek`; the whole `:11` row is in `PrThreadResolved`; `outdated` is in `PrThreadOutdated`; `invoice.go` is in `ChangesCommittedFile`

#### Scenario: Comments tab folds a file
- **WHEN** the cursor is on the `:22` row of the Comments tab and `h` is pressed in normal mode
- **THEN** the `invoice.go` row is folded and current, and no `:13`, `:22` or `:11` row is listed

#### Scenario: Comments tab shows a fetch failure
- **WHEN** the fake `gh` answers `query ReviewThreads` with exit 1 and `error connecting to pgw.dev` and the Comments tab is shown
- **THEN** its rows after the header are `PR comments unavailable: error connecting to pgw.dev` in `PrPeekMeta`, and the Local and Branch tabs still list their files

#### Scenario: Comments tab matches the approved render
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of the `billing-branch` fixture with `pr482` served, `require("gleb.pr").now` stubbed at 2026-01-02T01:00:00Z, the `changes.review` action runs three times, the panel cursor moves to the `:22` row, 100 ms pass and the editor window's view is restored with `winrestview({ topline = 6 })`
- **THEN** the screen matches the approved render "Proposed — Comments tab (r2_comments)" of the pr-comments-view design.md, text and colour mask

### Requirement: Comments tab selection
Moving the panel cursor onto a thread row SHALL, after the panel's 50 ms debounce, close the panel-owned diff view and show the thread's file in the editor window with its cursor on the mapped line, focus staying in the panel. An unmapped thread SHALL show its `diffHunk` in a read-only `diff` buffer instead. A file row SHALL show the file at its first thread.

#### Scenario: Selecting a thread shows its line
- **WHEN** the panel cursor moves onto the `:22` row of the Comments tab and 100 ms pass
- **THEN** the editor window shows `internal/billing/invoice.go` with its cursor on line 22, the current window is the `gleb-changes` window and no `gleb-diff` window remains

#### Scenario: Selecting an unmapped thread shows its diff hunk
- **WHEN** the served threads add a `LEFT`-side thread on `invoice.go` line 9 and the panel cursor moves onto its row and 100 ms pass
- **THEN** the editor window shows a buffer with filetype `diff`, `modifiable` off, whose lines are that thread's `diffHunk`

### Requirement: Comments tab Enter
`<CR>` (`changes.open`) on a thread row SHALL edit the thread's file in the editor window with the cursor on the mapped line and focus that window; on an unmapped thread it SHALL focus the `diffHunk` buffer. The panel SHALL stay open on the Comments tab.

#### Scenario: Enter on a thread opens its line
- **WHEN** the panel cursor is on the `:22` row of the Comments tab and `<CR>` is pressed in normal mode
- **THEN** the current window edits `internal/billing/invoice.go` with its cursor on line 22, and the `gleb-changes` window is still open on the Comments tab

#### Scenario: Enter on an unmapped thread shows its diff hunk
- **WHEN** line 22 is removed from the edited `invoice.go`, the panel cursor is on its `:22` thread and `<CR>` is pressed in normal mode
- **THEN** the current window is a read-only `diff` buffer containing that thread's `diffHunk`, and the panel stays open on Comments

### Requirement: Thread peeks
For each mapped, non-outdated thread of a file, an editor window SHALL draw `gleb_pr_peek` virt_lines under its line, from the line's indent. Open: `╰─ <icon> <author> <first line>` plus ` +1 reply` or ` +<n> replies`, expanded to the whole thread in a box while the window is current with its cursor on the line, or the thread is selected in the current Comments tab. Resolved: one `╰─ <check> Resolved · <author>: <first line>` line. Peeks SHALL follow `GlebPrThreads`.

#### Scenario: Open threads peek as one line
- **WHEN** `internal/billing/invoice.go` of the `billing-branch` fixture is edited in a 100-column window with `pr482` fetched and the cursor on line 18
- **THEN** line 22 has one `gleb_pr_peek` virt_line whose text, trimmed, is `╰─ ` U+F0188 ` maria.k Should a nil rate mean no tax at all? +1 reply`, with `╰─ ` in `PrPeekMeta`, the icon in `PrPeekIcon`, `maria.k` in `PrPeekAuthor`, the text in `PrPeek` and ` +1 reply` in `PrPeekMeta`; line 13 has `╰─ ` U+F0188 ` ivan.p Rate or *Rate here?`

#### Scenario: Peek expands at the cursor line
- **WHEN** the cursor then moves to line 22, then to line 23
- **THEN** with the cursor on line 22 that line has eight virt_lines: a top border holding ` PR #482 · 2 comments `, `maria.k · 2h`, its two body lines, `gleb-beloded · 1h`, its two body lines and a bottom border, each between `│` borders; with the cursor on line 23 it has one virt_line again

#### Scenario: Resolved threads fold to one grey line
- **WHEN** the cursor is moved to line 11
- **THEN** line 11 has exactly one virt_line, starting `╰─ ` U+F00C ` Resolved · ivan.p: Should ID stay a string?`, all in `PrThreadResolved`

#### Scenario: Outdated threads are hidden in code
- **WHEN** `internal/billing/tax.go` is edited with `pr482` fetched
- **THEN** its buffer has no `gleb_pr_peek` extmark

#### Scenario: Peeks follow the threads
- **WHEN** the served page drops `PRRT_t2` and `pr.refresh` runs while `invoice.go` is shown
- **THEN** after `GlebPrThreads` line 13 has no virt_line and line 22 still has its peek

#### Scenario: Editor peeks match the approved render
- **WHEN** the approved Comments tab screen continues with the editor window made current and `winrestview({ lnum = 18, topline = 6 })`
- **THEN** the screen matches the approved render "Proposed — peeks in the editor (r2_comments_peek)" of the pr-comments-view design.md, text and colour mask

### Requirement: Peek text cut
A collapsed or resolved peek and a Comments tab row SHALL show only the first line of the comment. When it is wider than the space left (the window's text width minus the indent and the rest of the row), it SHALL be cut at the last word boundary that leaves room for `…`, or hard-cut when one word is too long; no room gives an empty text and no separating space.

#### Scenario: Peek text is cut at a word boundary
- **WHEN** `require("gleb.pr.peek").truncate(text, width)` runs for `Should a nil rate mean no tax at all?\nA missing config would silently drop tax.` at 34 and 40, `Rate or *Rate here?` at 16, `Supercalifragilistic` at 8, and any text at 0
- **THEN** it returns `Should a nil rate mean no tax at…`, `Should a nil rate mean no tax at all?`, `Rate or *Rate…`, `Superca…` and an empty string

#### Scenario: Peek cut follows window width
- **WHEN** an editor or diff window showing a peek is narrowed and widened
- **THEN** its collapsed text and expanded box are redrawn to fit the new text width

#### Scenario: Resolved thread matches the approved render
- **WHEN** the approved peek screen is shown
- **THEN** its editor rows of lines 11 and 12 match the approved render "Proposed — resolved thread, smart cut (r3_truncate)" of the pr-comments-view design.md, text and colour mask

### Requirement: Diff view peeks
A diff view whose right side is a file of a root with a pull request SHALL draw the same peeks in its right window, mapped onto the right side's lines, with as many blank virt_lines at the aligned row of the left window, so rows stay aligned. Editor peeks SHALL not draw in diff windows, so a file shown in both gets each peek once per window.

#### Scenario: Diff view peeks keep the panes aligned
- **WHEN** the Branch tab of the `billing-branch` fixture shows the diff of `invoice.go` with `pr482` fetched
- **THEN** the right window has the one-line `PRRT_t1` peek under right line 22 and the left window one blank virt_line at that row, and the last left and right lines stay on the same screen row

#### Scenario: Local diff peeks once
- **WHEN** the Local tab shows the diff of `invoice.go`, whose right side is the file buffer
- **THEN** the right window shows the `PRRT_t1` peek once and the left window holds one blank virt_line at its row

#### Scenario: Diff peek cut follows pane width
- **WHEN** the Branch diff of `invoice.go` is widened across a `VimResized` event
- **THEN** its right-side peek is redrawn to use the wider pane's text width

### Requirement: Thread navigation
`pr.next_thread` and `pr.prev_thread` ("Next Review Thread", "Previous Review Thread", `Git | Pull Request`, no key) SHALL move the cursor of the current editor or diff window to the next or previous line with an open, mapped thread in its buffer; past the last, an editor window SHALL edit the next file in Comments tab order at its first thread. With none left they SHALL notify `No next thread` or `No previous thread` at INFO.

#### Scenario: pr.next_thread visits the open threads
- **WHEN** `invoice.go` of the `billing-branch` fixture is edited with `pr482` fetched, the cursor is on line 1 and the `pr.next_thread` action runs three times
- **THEN** the cursor is on line 13, then line 22, then still on line 22 with `No next thread` notified at INFO

#### Scenario: pr.prev_thread goes back
- **WHEN** the cursor is on line 30 and the `pr.prev_thread` action runs three times
- **THEN** the cursor is on line 22, then line 13, then still on line 13 with `No previous thread` notified at INFO

#### Scenario: Thread actions are unbound Find Action entries
- **WHEN** the action catalog and `settings/keymap.json` are read after startup
- **THEN** the catalog holds `pr.next_thread` and `pr.prev_thread` with the titles above in `Git | Pull Request` and `changes.show_comments` titled `Show Pull Request Comments` in `View | Tool Windows`, and none has a shortcut

### Requirement: Review highlight colours
The PR groups SHALL come from the palette and survive a colorscheme change: `PrPeek` fg0, `PrPeekAuthor` aqua bold, `PrPeekIcon` yellow, `PrPeekMeta` grey1, `PrThreadResolved` grey0 italic, `PrThreadOutdated` orange, and `ChangesTabComments` bg0 on yellow, bold.

#### Scenario: Review highlight colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `PrPeek` has `fg` fg0, `PrPeekAuthor` `fg` aqua and bold, `PrPeekIcon` `fg` yellow, `PrPeekMeta` `fg` grey1, `PrThreadResolved` `fg` grey0 and italic, `PrThreadOutdated` `fg` orange, and `ChangesTabComments` `fg` bg0, `bg` yellow and bold
