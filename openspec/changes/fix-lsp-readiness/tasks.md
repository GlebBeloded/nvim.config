## 1. Restore the authorized readiness contract
Scenarios: `lsp: lua_ls ready within 1 s in this config`
- [x] 1.1 Restore the ADDED-only 1 s readiness delta and remove the direct main-spec edit
- [x] 1.2 Restore the lua_ls test's 1000 ms bound and the user's Decision text verbatim
- [x] 1.3 Remove the unapproved serial-run harness and its code-restating documentation

## Blocked

1. **lua_ls with lazydev.** The authorized 1 s scenario measures about 2.1–2.25 s with lazydev retaining typed `vim.*` metadata. Meeting the scenario requires a user decision: narrow or disable lazydev's runtime metadata, accept untyped `vim.*`, or accept a higher lua_ls bound.
2. **Timing under parallel test load.** The 1 s fixture scenarios can exceed their bounds under the full parallel suite. Running readiness cases serially is a harness change that still needs the user's go-ahead; load-scaled bounds are forbidden by the existing constraints.
