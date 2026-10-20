## ADDED Requirements

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
