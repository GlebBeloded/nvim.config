## ADDED Requirements

### Requirement: Thread window
`pr.open_thread` ("Open Review Thread", `Git | Pull Request`, no key) SHALL open the thread on the cursor line of an editor or diff window (the first open one; none: INFO `No thread on this line`) in a rounded float centred above the statusline, `min(72, columns - 4)` wide, titled ` <file>:<line> · PR #<n> · <open|resolved|outdated> `: the commented line (or the `diffHunk` when unmapped), each comment's author, age and body, a `Reply` rule, the reply area, and the hint row under a rule.

#### Scenario: Open thread shows the thread centred
- **WHEN** a `100x30` screen edits `internal/billing/invoice.go` of the `billing-branch` fixture with the `pr482` responses fetched, the cursor is on line 22 and the `pr.open_thread` action runs
- **THEN** the thread window spans screen rows 6 to 23 and columns 15 to 86, its top border holds ` invoice.go:22 · PR #482 · open `, its text holds `maria.k · 2h`, `Should a nil rate mean no tax at all?` and `gleb-beloded · 1h`, and the current window is its empty reply area, filetype `gleb-pr-thread`, in normal mode

#### Scenario: Open thread without a thread on the line
- **WHEN** the cursor is on line 1 of that file and the `pr.open_thread` action runs
- **THEN** `No thread on this line` is notified at INFO and no `gleb-pr-thread` window exists

#### Scenario: An unmapped thread window shows its diff hunk
- **WHEN** the served threads add a `LEFT`-side thread on `invoice.go` and `<CR>` is pressed on its Comments tab row
- **THEN** the first lines of the thread window are the last four lines of its `diffHunk`, and its title ends with `· open`

#### Scenario: Thread window matches the approved render
- **WHEN** the approved Comments tab screen of the pr-comments-view design.md continues with `<CR>` on the `:22` row
- **THEN** the screen matches the approved render "Proposed — thread window (r3_thread_center)" of the pr-thread-window design.md, text and colour mask

### Requirement: Thread window keys
The thread window's normal-mode keys SHALL come from `pr.thread_*` actions scoped to `gleb-pr-thread`, and its hint row SHALL name them: `Reply ↩ · Resolve R · Open on web gx · Close q`, `Unresolve R` for a resolved thread, without `Reply ↩` or `Resolve R` when the viewer may not. `<CR>` on an empty reply SHALL start Insert mode; `gx` SHALL open the first comment's URL; `q`, or focus leaving the window, SHALL close it and keep the draft for the thread.

#### Scenario: Enter on an empty reply starts writing
- **WHEN** the thread window of `PRRT_t1` is open with an empty reply area and `<CR>` is pressed in normal mode
- **THEN** the mode is Insert and the cursor is in the reply area

#### Scenario: gx opens the thread on the web
- **WHEN** `vim.ui.open` is stubbed in the child, the thread window of `PRRT_t1` is open and `gx` is pressed in normal mode
- **THEN** `vim.ui.open` was called once with the url of the thread's first comment

#### Scenario: q keeps the draft for the next open
- **WHEN** `Draft` is typed in the reply area, `<Esc>` and `q` are pressed, then the `pr.open_thread` action runs again on line 22
- **THEN** no `gleb-pr-thread` window existed after `q`, and the reopened reply area holds `Draft`

#### Scenario: Resolved thread offers Unresolve
- **WHEN** the cursor is on line 11 and the `pr.open_thread` action runs
- **THEN** the title ends with `· resolved` and the hint row reads `Reply ↩ · Unresolve R · Open on web gx · Close q`

#### Scenario: Resolve is hidden without permission
- **WHEN** the served `PRRT_t1` has `viewerCanResolve` false, its thread window is open and `R` is pressed in normal mode
- **THEN** the hint row reads `Reply ↩ · Open on web gx · Close q` before and after `R`, and no `mutation` line is logged

#### Scenario: Thread window keys come from the shortcut file
- **WHEN** the thread window is open after `VeryLazy` and the reply buffer's normal mappings are enumerated
- **THEN** `<CR>`, `R`, `gx` and `q` invoke `pr.thread_send`, `pr.thread_resolve`, `pr.thread_open_web` and `pr.thread_close` as assigned in `settings/keymap.json`, with descriptions `Git | Pull Request: <Title>`

### Requirement: Reply confirmation
`<CR>` in normal mode with a non-empty reply SHALL turn the hint row into `Send this reply to <first author> on <host>?` (`PrConfirm`) and `Send y · Keep editing n` right-aligned (`PrConfirmHint`), the reply buffer read-only with filetype `gleb-pr-confirm`. `y` (`pr.confirm_yes`) SHALL send it with `addPullRequestReviewThreadReply`; `n` or `<Esc>` (`pr.confirm_no`) SHALL restore the hints and Insert mode at the draft's end. Nothing SHALL be sent without `y`.

#### Scenario: Enter asks before sending a reply
- **WHEN** `Defaulting to Rate(0) now, see e325463.` is typed in the reply area of `PRRT_t1`, then `<Esc>` and `<CR>` are pressed
- **THEN** the hint row reads `Send this reply to maria.k on pgw.dev?` and `Send y · Keep editing n`, the reply buffer's filetype is `gleb-pr-confirm` and not `modifiable`, its `y`, `n` and `<Esc>` mappings invoke `pr.confirm_yes`, `pr.confirm_no` and `pr.confirm_no`, and no `mutation` line is logged

#### Scenario: y sends the reply
- **WHEN** the send question is shown and `y` is pressed
- **THEN** one `mutation AddReply` line is logged with `-f id=PRRT_t1` and `-f body=Defaulting to Rate(0) now, see e325463.`, `Reply sent` is notified at INFO, one more `query ReviewThreads` line follows, and the reply area is empty with the normal hint row

#### Scenario: n keeps editing
- **WHEN** the send question is shown and `n` is pressed
- **THEN** the normal hint row is back, the mode is Insert with the cursor after `e325463.`, and no `mutation` line is logged

#### Scenario: A failed reply keeps the draft
- **WHEN** the fake `gh` answers `mutation AddReply` with exit 1 and `HTTP 502: Bad Gateway`, and `y` is pressed on the send question
- **THEN** `Reply failed: HTTP 502: Bad Gateway` is notified at ERROR, the reply area still holds the draft and the normal hint row is back

#### Scenario: The reply goes to gh as one argument
- **WHEN** the reply `it's "fine" $(touch /tmp/pwned) @notes.md` is sent with `y`
- **THEN** the fake `gh` log holds `-f body=it's "fine" $(touch /tmp/pwned) @notes.md` and `/tmp/pwned` does not exist

#### Scenario: Send confirmation matches the approved render
- **WHEN** the approved thread window screen continues with `i`, typing `Defaulting to Rate(0) now, see e325463.`, `<Esc>` and `<CR>`
- **THEN** the screen matches the approved render "Proposed — send confirmation (r3_confirm_footer)" of the pr-thread-window design.md, text and colour mask

### Requirement: Resolve confirmation
`R` (`pr.thread_resolve`) SHALL turn the hint row into `Resolve this thread?` and `Resolve y · Cancel n`, or `Unresolve this thread?` and `Unresolve y · Cancel n` for a resolved thread. `y` SHALL run `resolveReviewThread` or `unresolveReviewThread`, then refresh the threads, update the title and notify `Thread resolved` or `Thread unresolved`; `n` SHALL restore the hints. A failure SHALL notify `Resolve failed: <message>` or `Unresolve failed: <message>` at ERROR.

#### Scenario: R asks before resolving
- **WHEN** the thread window of `PRRT_t1` is open and `R` is pressed in normal mode
- **THEN** the hint row reads `Resolve this thread?` and `Resolve y · Cancel n`, and no `mutation` line is logged

#### Scenario: y resolves the thread
- **WHEN** the resolve question is shown, the served page is switched to one with `PRRT_t1` resolved, and `y` is pressed
- **THEN** one `mutation ResolveThread` line is logged with `-f id=PRRT_t1`, `Thread resolved` is notified at INFO, and after `GlebPrThreads` the title ends with `· resolved`

#### Scenario: y unresolves a resolved thread
- **WHEN** the thread window of `PRRT_t4` is open, `R` and then `y` are pressed
- **THEN** the question read `Unresolve this thread?`, one `mutation UnresolveThread` line is logged with `-f id=PRRT_t4`, and `Thread unresolved` is notified at INFO

#### Scenario: A failed resolve is reported
- **WHEN** the fake `gh` answers `mutation ResolveThread` with exit 1 and `Resource not accessible by integration`, and `R` and `y` are pressed in the thread window of `PRRT_t1`
- **THEN** `Resolve failed: Resource not accessible by integration` is notified at ERROR, the title still ends with `· open` and the normal hint row is back

### Requirement: Thread mutations
Replies and resolve changes SHALL run as `gh api graphql` argument lists (`-f query=mutation <AddReply|ResolveThread|UnresolveThread>…`, `-f id=<thread id>`, and `-f body=<draft>` for a reply) with `GH_HOST` set to the PR host and no shell. While one runs the hint row SHALL read `Sending...` or `Resolving...` and `y`/`n` do nothing. They SHALL be the only writes to GitHub.

#### Scenario: A mutation shows progress and ignores keys
- **WHEN** `FAKE_GH_SLEEP` is 1, `y` is pressed on the send question, then `y` again within 500 ms
- **THEN** the hint row reads `Sending...` during the call and exactly one `mutation AddReply` line is logged

### Requirement: Thread window colours
`PrConfirm` SHALL be yellow, bold, on `blend(yellow, bg0, 0.8)`; `PrConfirmHint` fg1 on the same background; `PrReplyPlaceholder` grey0 italic for the `Write a reply…` placeholder. The frame SHALL use `FloatBorder` and `FloatTitle`, the hints `PickerHint`.

#### Scenario: Thread window colours
- **WHEN** the full config has loaded and `:colorscheme gruvbox-material` runs again
- **THEN** `PrConfirm` has `fg` yellow, `bg` the 80 % blend of yellow into bg0 and bold; `PrConfirmHint` has `fg` fg1 and the same `bg`; `PrReplyPlaceholder` has `fg` grey0 and italic

## MODIFIED Requirements

### Requirement: Comments tab Enter
`<CR>` (`changes.open`) on a thread row SHALL edit the thread's file in the editor window with the cursor on the mapped line, or show the `diffHunk` buffer for an unmapped thread, and then open the thread window for it (`pr.open_thread`), focused on its reply area. The panel SHALL stay open on the Comments tab.

#### Scenario: Enter on a thread opens its line
- **WHEN** the panel cursor is on the `:22` row of the Comments tab and `<CR>` is pressed in normal mode
- **THEN** the editor window edits `internal/billing/invoice.go` with its cursor on line 22, the current window is the reply area of the `PRRT_t1` thread window, and the `gleb-changes` window is still open on the Comments tab
