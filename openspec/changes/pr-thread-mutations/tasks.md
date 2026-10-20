## 1. Recorded responses
- [ ] 1.1 Learn the request and response shapes of `addPullRequestReviewThreadReply`, `resolveReviewThread` and `unresolveReviewThread` on a GlebBeloded/nvim.config PR through `gh` (proposal Decision), and record the success and `errors` responses in `tests/fixtures/gh/mutations.lua`

## 2. Mutation requests
Scenarios: `pr: A reply request passes the body as one argument`, `pr: Resolve requests name the thread`, `pr: A failed mutation returns its message`
- [ ] 2.1 Write the scenarios in `tests/unit/pr/test_gh.lua` with a stub `run` and the recorded responses, and see them fail
- [ ] 2.2 Add `reply` and `set_resolved` with the three documents to `lua/gleb/pr/gh.lua`
- [ ] 2.3 Run the file and see it pass
- [ ] 2.4 Run `make check` and see it pass
