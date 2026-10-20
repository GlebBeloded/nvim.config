## ADDED Requirements

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
