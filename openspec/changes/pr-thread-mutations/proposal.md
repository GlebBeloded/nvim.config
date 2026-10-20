## Why

Kind: feature

Split out of `pr-thread-window` (user, 2026-10-20: "Split it"), so it runs beside `pr-comments-view` instead of
waiting for it: the GitHub writes behind the thread window's reply and resolve need only `lua/gleb/pr/gh.lua`,
which `pr-comments-view` does not change. `pr-thread-window` keeps the window, its keys, confirmations and
colours, and calls these functions.

## What Changes

- **Mutation requests** in `lua/gleb/pr/gh.lua` (pr-thread-window design.md, Decision 5):
  - `require("gleb.pr.gh").reply(review, thread_id, body, run?, callback)` runs `mutation AddReply`
    (`addPullRequestReviewThreadReply`).
  - `require("gleb.pr.gh").set_resolved(review, thread_id, resolved, run?, callback)` runs
    `mutation ResolveThread` (`resolveReviewThread`) or `mutation UnresolveThread` (`unresolveReviewThread`).
  - Each is `gh api graphql -f query=<one-line document> -f id=<thread id>`, plus `-f body=<draft>` for a
    reply: an argument list with no shell, `GH_HOST` set to the PR host, the same env and timeout as the
    queries. `@`, quotes and `$(…)` in the body reach GitHub as typed.
  - The callback gets `(true)` on success or `(false, message)`: `gh.failure`'s text without its
    `PR comments unavailable: ` prefix (a GraphQL `errors[1].message` included).
- **Fixtures recorded from the real API** (user Decision, 2026-10-20): the agent learns the exact request and
  response shapes on this repo's own PRs (GlebBeloded/nvim.config, through `gh`), records the responses under
  `tests/fixtures/gh/`, and tests against them. Tests never call the network.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `pr`: Added "Thread mutation requests".

## Impact

- Code: `lua/gleb/pr/gh.lua` (the two functions and the three documents).
- Tests: unit cases in `tests/unit/pr/test_gh.lua`; recorded responses in `tests/fixtures/gh/mutations.lua`.
- Plugins, keymaps, UI: none (`pr-thread-window` adds the UI).
- Out of scope: everything the thread window shows or asks; that stays in `pr-thread-window`.

## Decision (user, 2026-10-20)

- Don't guess the GitHub API: the agent may call the real API on this repo's own PRs (GlebBeloded/nvim.config, through
  `gh`) to learn the exact request and response shapes, then record those responses as fixtures and test against the
  mocked responses. Tests never call the network.
