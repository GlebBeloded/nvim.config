## ADDED Requirements

### Requirement: Thread mutation requests
`require("gleb.pr.gh").reply(review, thread_id, body, run?, callback)` and `set_resolved(review, thread_id, resolved, run?, callback)` SHALL run `gh api graphql` as an argument list (`-f query=mutation <AddReply|ResolveThread|UnresolveThread>…`, `-f id=<thread id>`, and `-f body=<body>` for a reply) with `GH_HOST` set to the PR host and no shell, and call back `(true)` on success or `(false, message)` with `gh.failure`'s message without its `PR comments unavailable: ` prefix.

#### Scenario: A reply request passes the body as one argument
- **WHEN** `reply(pr, "PRRT_t1", body, run)` runs with a stub `run` and the body `it's "fine" $(touch /tmp/pwned) @notes.md`
- **THEN** `run` gets one argument list starting `gh api graphql`, holding `-f` `query=mutation AddReply…`, `-f` `id=PRRT_t1` and `-f` `body=it's "fine" $(touch /tmp/pwned) @notes.md` as single elements, with `GH_HOST=pgw.dev` in its env

#### Scenario: Resolve requests name the thread
- **WHEN** `set_resolved(pr, "PRRT_t1", true, run)` and `set_resolved(pr, "PRRT_t4", false, run)` run with a stub `run` answering the recorded responses
- **THEN** the first argument list holds `query=mutation ResolveThread…` and `id=PRRT_t1`, the second `query=mutation UnresolveThread…` and `id=PRRT_t4`, and both callbacks get `true`

#### Scenario: A failed mutation returns its message
- **WHEN** the stub answers `reply` with exit 1 and stderr `HTTP 502: Bad Gateway`, then `set_resolved` with exit 0 and the recorded `errors` response `Resource not accessible by integration`
- **THEN** the callbacks get `false, "HTTP 502: Bad Gateway"` and `false, "Resource not accessible by integration"`
