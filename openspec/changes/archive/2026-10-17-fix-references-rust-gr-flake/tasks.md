## 1. Wait for rust-analyzer readiness before `gr`
Scenarios: `references: gr classifies every Rust variable usage`
- [x] 1.1 Use the recorded gate failure as the failing evidence: `FAIL in tests/integration/references/test_kind.lua | references: gr classifies every Rust variable usage | renders every usage kind:` returned only the declaration as `other` instead of the expected write and read usages
- [x] 1.2 Update the `open_references` test helper to wait for rust-analyzer's `experimental/serverStatus` notification with `quiescent = true` before its existing references-readiness probe and real `gr` key press; keep the existing readiness behavior for other servers and keep the assertion unchanged
- [x] 1.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="references: gr classifies every Rust variable usage"` and see it pass

## Agent decisions

- Wrap rustaceanvim's per-client server-status handler before opening the Rust buffer, preserving its original behavior, because rustaceanvim routes this notification around the global LSP handler.
