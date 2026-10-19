## Context

`git-branch-base` resolves, per repository root, the branch, HEAD, base and merge-base, and the open pull
request from `gh pr view` (`require("gleb.git.base")`: `resolve`, `get`, `refresh`, `User GlebGitBaseChanged`;
`info.pr` = `number`, `url`, `base_ref_name`, `base_ref_oid`, `head_ref_name`, `head_ref_oid`, `host`).
`git-changes-tabs` adds the Local and Branch tabs and the `billing-branch` fixture. This change adds the review
threads behind the later Comments tab, peeks and thread window.

GraphQL facts, checked on pgw.dev (GHES 3.22.1) by schema introspection only:

- `PullRequestReviewThread` has `id isResolved isOutdated isCollapsed path line originalLine startLine
  originalStartLine diffSide startDiffSide subjectType resolvedBy viewerCanReply viewerCanResolve
  viewerCanUnresolve comments`.
- `PullRequestReviewComment` has `author body createdAt url diffHunk line originalLine startLine outdated commit
  originalCommit replyTo state`.
- Connections take `first` 1..100 and expose `pageInfo { hasNextPage endCursor }`.
- `line` is relative to the pull request's head, and is null when the thread is outdated. `originalLine` is
  relative to `originalCommit`. Rate limiting is disabled on pgw.dev.

Prior art, read as data (sources in the lead's scratch dir):

- octo.nvim (`lua/octo/gh/queries.lua`) and gh-review.nvim (`lua/gh_review/graphql.lua`) fetch
  `reviewThreads(first: 100)` without paging comments. They place threads by `line` in a diff of the PR head,
  never on the working file.
- IntelliJ's `GHPRReviewFileEditorModel` shifts thread lines through the changes between the PR head and the
  open document (`ReviewInEditorUtil.transferLineToAfter`).
- snacks.nvim's `gh` module renders PR comments in its own buffers.

None maps threads onto an edited working file, which is what the user's peeks need.

## Goals / Non-Goals

**Goals:**
- One cached, typed list of review threads per root with a pull request, fetched in the background.
- Every thread either mapped to a line of the file as it is now, or unmapped with a reason.
- Hermetic tests: canned GraphQL responses, no network.

**Non-Goals:**
- UI (the next two changes), writes (`pr-thread-window`), pending reviews, forks.

## Decisions

1. **Module and API** (`lua/gleb/pr/`; rule 1.3: `threads.lua` is pure):

   ```lua
   ---@class gleb.pr.Comment
   ---@field id string
   ---@field author string login, "ghost" when GitHub returns null
   ---@field body string Markdown as written
   ---@field created_at string ISO 8601
   ---@field url string
   ---@field diff_hunk string
   ---@field reply_to? string comment id

   ---@class gleb.pr.Thread
   ---@field id string
   ---@field path string repository-relative
   ---@field side "RIGHT"|"LEFT"
   ---@field line? integer at the PR head; nil when outdated
   ---@field start_line? integer
   ---@field original_line? integer
   ---@field original_commit? string full oid of the first comment's originalCommit
   ---@field resolved boolean
   ---@field outdated boolean
   ---@field subject "line"|"file"
   ---@field resolved_by? string
   ---@field can_reply boolean
   ---@field can_resolve boolean
   ---@field can_unresolve boolean
   ---@field comments gleb.pr.Comment[]

   ---@class gleb.pr.Review per root
   ---@field root string
   ---@field pr gleb.git.base.Pr
   ---@field host string pr.host, else the host of pr.url
   ---@field owner string from pr.url
   ---@field name string from pr.url
   ---@field head string pr.head_ref_oid the threads were fetched for
   ---@field threads gleb.pr.Thread[]
   ---@field fetched_at? integer

   ---@class gleb.pr.Location
   ---@field thread gleb.pr.Thread
   ---@field line? integer 1-based buffer line, nil when unmapped
   ---@field reason? "left side"|"file"|"missing commit"|"removed"
   ```

   - `M.refresh(root, opts?)`: fetches when the base has a pull request (`opts.force` skips the write
     throttle and always notifies).
   - `M.get(root)`: the cached `gleb.pr.Review` or nil, running nothing.
   - `M.locate(buf, callback?)`: returns the cached `gleb.pr.Location[]` of the buffer's file right away. When
     `git show` contents are missing, it loads them and calls `callback` with the full list.
   - `M.now()`: the clock, stubbed by tests.
   - `M.state` and `M.reset()` (rule 1.5).
   - Tunables at the top of `init.lua`: `WRITE_DEBOUNCE_MS = 1000`, `WRITE_MIN_INTERVAL_MS = 30000`,
     `GH_TIMEOUT_MS = 20000`.
2. **GraphQL documents** (`gh.lua`, one-line strings with named operations):
   - `query ReviewThreads($owner:String!,$name:String!,$number:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first: 100,after:$cursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated path line originalLine startLine originalStartLine diffSide subjectType resolvedBy{login} viewerCanReply viewerCanResolve viewerCanUnresolve comments(first: 100){pageInfo{hasNextPage endCursor} nodes{id author{login} body createdAt url diffHunk originalCommit{oid} replyTo{id}}}}}}}}`
   - `query ThreadComments($id:ID!,$cursor:String){node(id:$id){... on PullRequestReviewThread{comments(first: 100,after:$cursor){pageInfo{hasNextPage endCursor} nodes{…same fields…}}}}}`
   - The argv is `{ "gh", "api", "graphql", "-f", "query=" .. Q, "-f", "owner=" .. owner, "-f", "name=" ..
     name, "-F", "number=" .. n }`, plus `"-f", "cursor=" .. c` after the first page. Strings use `-f`, so
     an `@` is never read as a file; only the number uses `-F`.
   - env: `GH_HOST=<host>`, `GH_PROMPT_DISABLED=1`, `GH_NO_UPDATE_NOTIFIER=1`, `NO_COLOR=1`, with
     `timeout = GH_TIMEOUT_MS`. There is no shell (rule 6.4).
   - `fetch_threads(review, run, callback)` takes the runner, so unit tests drive pagination with a stub. It
     pages threads first, then each thread whose comments have `hasNextPage`, one call per page.
   - Owner and name come from `pr.url` (`https://<host>/<owner>/<name>/pull/<n>`).
3. **Anchors** (`threads.anchor(thread, head)`):

   | Thread | Anchor |
   |---|---|
   | `subject = "file"` | none, reason `file` |
   | `side = "LEFT"` | none, reason `left side` |
   | `line` set | `head`, `line` |
   | outdated, `original_line` set | `original_commit`, `original_line` |

   A `LEFT` thread sits on a line of the base side, which the working file no longer has. The Comments tab
   lists it with its `diffHunk`.
4. **Mapping** (`threads.map_line(from, to, line)`): `vim.text.diff(a, b, { result_type = "indices" })` over
   the joined lines, walking the hunks `{start_a, count_a, start_b, count_b}` in order:
   - a pure insertion (`count_a = 0`) at or above the line shifts it by `count_b`;
   - a hunk containing the line maps it to `start_b + min(line - start_a, count_b - 1)`, or to nil when
     `count_b = 0`;
   - a hunk above the line shifts it by `count_b - count_a`.

   Verified with Neovim 0.12 on the three scenario tables. `locate(buf)` reads the buffer's lines, gets
   `git show <oid>:<path>` once per `oid:path` (cached; a failing `git cat-file -e <oid>^{commit}` means
   `missing commit`, with no notification) and maps every anchored thread of the buffer's path. The buffer's
   path is made repository-relative with the root normalized as in the changes panel.
5. **Cache and refresh.**
   - `state.by_root[root]` holds the `gleb.pr.Review`, a generation counter, `in_flight`, `pending`,
     `last_write_fetch` and the reported failure kinds.
   - Triggers:
     - `pr.refresh` (forced);
     - `changes.review` when it opens a closed panel;
     - `BufWritePost` of a normal file under a root whose base has a pull request (augroup `gleb_pr`;
       debounced `WRITE_DEBOUNCE_MS`; skipped when the last write-triggered fetch is younger than
       `WRITE_MIN_INTERVAL_MS`);
     - `User GlebGitBaseChanged` when the root's pull request number or `head_ref_oid` differs from the
       cached `head`.
   - A trigger while a fetch runs sets `pending`, and one more fetch follows.
   - A result whose generation is not the latest is dropped (rule 6.3).
   - A successful fetch replaces `threads`, sets `head`, clears the reported failure kinds and fires
     `User GlebPrThreads` with `data = { root = root }`. Consumers redraw on it.
   - Contents per `oid:path` live for the session (`state.blobs`), bounded at 200 entries, oldest dropped
     first.
6. **Errors.** `gh.failure(result, host)` maps a `vim.system` result to `{ kind, message }`:

   | Input | Kind | Message after `PR comments unavailable: ` |
   |---|---|---|
   | `vim.fn.executable("gh") == 0` | `missing` | `gh not found` |
   | stderr contains `gh auth login`, or `HTTP 401` | `auth` | `gh is not authenticated for <host>` |
   | exit 0, JSON with `errors[1].message` | `graphql` | that message |
   | any other non-zero exit (timeout 124 included) | `failed` | first stderr line, else `gh exited <code>` |

   - A background fetch notifies at WARN only when its kind is not yet in the root's reported set.
   - `pr.refresh` always notifies.
   - The cache is never cleared by a failure, and the base, panel and signs are separate modules that
     never see it.
7. **Fake `gh` routing.** `tests/fixtures/bin/gh` (from `git-branch-base`) keeps its log line and its
   `FAKE_GH_STDOUT` mode. When `FAKE_GH_DIR` is set, the response file is chosen by call:

   | Call | File in `$FAKE_GH_DIR` |
   |---|---|
   | `pr view …` | `pr.json` |
   | `api graphql` with `query=query <Op>` or `query=mutation <Op>` | `<Op>.json`, or `<Op>-<cursor>.json` when `cursor=<c>` is passed |

   - A sibling `<file>.code` sets the exit code and `<file>.stderr` the stderr.
   - A missing file exits 1 with `fake gh: no response for <name>`.
   - `FAKE_GH_SLEEP` still applies.
   - `tests/fixtures/gh/pr482.lua` returns a function of the `billing-branch` manifest that yields the files
     (name → content). The test helper writes them into a temp `FAKE_GH_DIR` and sets the env in the child.

## Fixture

`billing-branch` (from `git-changes-tabs`): `feat/tax` at `e325463` over `main` at `4ccefde`. The commits are
`b5435c5` (`add tax.go`), `07cb52e` and `e325463`. `invoice.go` has an unstaged edit on line 11. The `pr482`
responses:

- `pr.json`: `{"number":482,"url":"https://pgw.dev/finteqhub/billing/pull/482","state":"OPEN","baseRefName":"main","baseRefOid":"<4ccefde…>","headRefName":"feat/tax","headRefOid":"<e325463…>"}`.
- `ReviewThreads.json`: one page, `hasNextPage` false, four threads:

  | id | path | line / original | state | comments (author, createdAt, body) |
  |---|---|---|---|---|
  | `PRRT_t1` | `internal/billing/invoice.go` | 22 / 22 | open | `maria.k` 2026-01-01T23:00:00Z `Should a nil rate mean no tax at all?\nA missing config would silently drop tax.`; `gleb-beloded` 2026-01-02T00:00:00Z `Good catch, defaulting to Rate(0) and\nlogging a warning.` (replyTo the first) |
  | `PRRT_t2` | `internal/billing/invoice.go` | 13 / 13 | open | `ivan.p` 2026-01-01T21:00:00Z `Rate or *Rate here?` |
  | `PRRT_t3` | `internal/billing/tax.go` | null / 18 at `b5435c5` | open, outdated | `maria.k` 2026-01-01T02:00:00Z `Round half-even?` |
  | `PRRT_t4` | `internal/billing/invoice.go` | 11 / 11 | resolved by `gleb-beloded` | `ivan.p` 2026-01-01T21:00:00Z `Should ID stay a string? The ledger numbers invoices with integers, so a string lets a malformed ID reach the export unchecked.\nIf we keep it, validate it in New.` |

  - Every thread is `diffSide` `RIGHT`, `subjectType` `LINE`, `viewerCanReply` and `viewerCanResolve` true,
    and `viewerCanUnresolve` true only on `PRRT_t4`.
  - Comment ids are `PRRRC_c1`… in table order.
  - urls are `https://pgw.dev/finteqhub/billing/pull/482#discussion_r<id digits>`.
  - Each `diffHunk` is the real `git diff 4ccefde e325463` hunk header and lines up to the commented line.
- Cases that need more (pagination, a missing commit, `LEFT`/`FILE` threads, failures) patch the table before
  it is written.

## Risks / Trade-offs

- **Head not fetched locally.** When someone else pushed to the branch and the user has not fetched,
  `headRefOid` is not a local commit, and every thread on that head is `missing commit` until a fetch.
  Accepted: the editor never fetches (`git-branch-base`). The Comments tab still lists the threads.
- **Approximate placement inside edited blocks.** A thread on a line the author rewrote lands on the
  rewritten block at the same offset. It can sit one or two lines off in a heavily edited block, which is
  better than vanishing.
- **Large pull requests.** Every thread and comment is fetched, 100 per call. A PR with 300 threads makes 3
  calls. That is acceptable against GHES without rate limits, and the calls are off the main loop.
- **Schema drift.** The fields were introspected on GHES 3.22.1. A future GHES dropping a field turns into a
  `graphql` failure WARN, not an error.

## Renders

No visible UI: this change only adds notifications and a Find Action entry. The renders come with
`pr-comments-view` and `pr-thread-window`.
