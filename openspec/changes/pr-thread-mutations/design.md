## Context

`lua/gleb/pr/gh.lua` already owns review-thread GraphQL documents, request options, process execution and failure
classification. The thread window needs reply and resolved-state writes through that transport, while its UI remains in
the separate `pr-thread-window` change.

## Goals / Non-Goals

- Add typed mutation entry points that preserve body text and use the existing host, prompt and timeout controls.
- Base request and response handling on responses recorded from this repository's real pull requests.
- Keep tests deterministic and offline.
- Do not add thread-window UI, keys, confirmations, refresh behavior or cache updates.

## Decisions

### Keep mutations in the existing transport module

The three one-line mutation documents and both exported functions live in `lua/gleb/pr/gh.lua`. A shared mutation
request path builds an argument list, uses the existing request options and normalizes completion before the public
callback runs. This keeps shell interpretation impossible and avoids a second GraphQL transport abstraction.

### Record real response envelopes, then test offline

The implementation task first invokes `gh` against GlebBeloded/nvim.config pull requests as authorized by the proposal,
then stores representative success and GraphQL-error envelopes in `tests/fixtures/gh/mutations.lua`. Unit tests pass
those fixtures through a stub runner; they never access the network.

### Normalize mutation failures at the transport boundary

Process and GraphQL failures continue through `gh.failure`, then the mutation callback removes only the established
`PR comments unavailable: ` prefix. Callers receive either `true` or `false, message` and do not need to understand
GitHub CLI result shapes.

## Risks / Trade-offs

- GitHub may change response envelopes; recorded fixtures make the expected contract explicit, while future API drift
  requires refreshing the fixtures deliberately.
- Recording responses mutates real review threads. The task is limited to this repository's own pull requests, as the
  user decision permits, and tests use only the saved responses afterward.
