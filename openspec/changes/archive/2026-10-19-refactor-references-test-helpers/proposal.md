## Why

Kind: refactor

The "send `textDocument/references` until the result has at least `minimum` locations, twice in a row" readiness loop
(`_G.references_ready`) is copied 13 times: `tests/render/cases.lua:181,241,302,368,436`,
`tests/screen/references/test_view.lua:665,723,781,840,904,970`, `tests/integration/references/test_kind.lua:169`,
`tests/integration/references/test_languages.lua:93`. Variants: `test_languages.lua` needs one non-empty result and
records `references_error`; `test_kind.lua:42-80` (`classify`) retries on "content modified" and can use
`documentHighlight`; `test_view`/`cases.lua` use a compact form. The rust-analyzer "quiescent" handler wrap/restore is
copied at `test_kind.lua:127-151`, `test_languages.lua:38-58` and `test_view.lua:635-662`. Reviews flagged it as a
minor in runs 10803b3a (×3), 96e6ec62 and 63bb65e7.

## What Changes

- `H.wait_references_ready(child, server, opts)` in `tests/helpers.lua` covering the variants as options (minimum,
  consecutive passes, content-modified retry, error capture), and `H.watch_rust_quiescent` / `H.wait_rust_quiescent`.
- Replace every copy; each case keeps its assertions, waits and bounds (no wait gets longer or looser).

## Impact

- `tests/helpers.lua`, `tests/render/cases.lua`, `tests/screen/references/test_view.lua`,
  `tests/integration/references/{test_kind,test_languages}.lua`.
