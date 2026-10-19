# Tasks

## 1. Upgrade rustaceanvim through a deterministic gate

Scenarios: `shortcuts: CHECK_LOCK=0 runs make check without the check lock`, `file-tree: Unchanged git status does not redraw the project tree`, `references: Rust usages in production and test code`

- [x] 1.1 Retain the failing tests: the recorded full gate is red for the shortcuts and file-tree scenarios, and the focused shortcuts case reproduces the non-`nil` holder leave time
- [x] 1.2 Synchronize the shortcuts fixture's external holder with the assertion instead of a fixed four-second lifetime, while still proving the unlocked check runs before that holder exits
- [x] 1.3 Make the file-tree case deliver an unchanged git result deterministically under full-suite load, while retaining the assertion that the tree buffer is never replaced
- [x] 1.4 Keep rustaceanvim pinned at `9cb125de42c0256ed1bc1f9ded8d8f0381317a17`; run the three scenario tests, `make quick`, and `make check`

## Agent decisions

- Release the external check-lock holder through a file handshake so the assertion, not elapsed time, ends its lifetime.
- Replay a real precomputed Git snapshot through the asynchronous refresh callbacks so the no-redraw contract remains realistic and deterministic.
