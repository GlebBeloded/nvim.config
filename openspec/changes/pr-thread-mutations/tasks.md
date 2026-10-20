## 1. Recorded responses and reply transport
Scenarios: `pr: A reply request passes the body as one argument`
- [x] 1.1 Learn the request and response shapes of `addPullRequestReviewThreadReply`, `resolveReviewThread` and `unresolveReviewThread` on a GlebBeloded/nvim.config PR through `gh`, record the success and `errors` responses in `tests/fixtures/gh/mutations.lua`, then write the test `pr: A reply request passes the body as one argument` in `tests/unit/pr/test_gh.lua` against a stub `run` and the recorded response and see it fail
- [x] 1.2 Add the three one-line mutation documents, shared argument-list transport, and `reply` to `lua/gleb/pr/gh.lua`, reusing the query request environment and timeout
- [x] 1.3 Run `make test FILE=tests/unit/pr/test_gh.lua CASE="A reply request passes the body as one argument"` and see it pass

## 2. Mutation requests
Scenarios: `pr: Resolve requests name the thread`, `pr: A failed mutation returns its message`
- [x] 2.1 Write the tests `pr: Resolve requests name the thread` and `pr: A failed mutation returns its message` in `tests/unit/pr/test_gh.lua` against a stub `run` and the recorded responses and see them fail
- [x] 2.2 Add `set_resolved` and shared success/error callback handling to `lua/gleb/pr/gh.lua`
- [x] 2.3 Run `make test FILE=tests/unit/pr/test_gh.lua CASE="Resolve requests name the thread"` and `make test FILE=tests/unit/pr/test_gh.lua CASE="A failed mutation returns its message"` and see them pass
- [ ] 2.4 Run `make check` and see it pass

## Agent decisions

- Mutation documents request only the created comment ID or the thread ID and resolved state, the smallest live-verified success payloads needed to establish each response envelope.
