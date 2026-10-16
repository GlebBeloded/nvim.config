## Context

See proposal.md (Why). Research (2026-10-16):
- No LSP server marks individual reference locations as test code. gopls' `gopls.packages` exposes `TestFiles`, but filename conventions are enough.
- rust-analyzer only exposes its TEST category through the `references.excludeTests` setting, not per location.
- JetBrains decides through test source roots plus `TestSourcesFilter` extensions; the Go plugin matches `*_test.go`.
- Conventions come from `go help test`, Jest's default `testMatch`, Vitest's default include, pytest discovery and busted.

## Goals / Non-Goals

**Goals:** one pure, table-driven answer to "is this test code" for every configured language, plus Rust inline tests.

**Non-Goals:** asking servers, reading project configs (jest.config, pytest.ini), and UI.

## Decisions

1. **Table, not code per language.** `PATTERNS = { go = { "_test%.go$" }, typescript = {...}, ... }` holds Lua patterns, matched against the path with `/` separators. Generic `SEGMENTS = { test = true, tests = true, spec = true, __tests__ = true }` apply to every filetype after the table. TS/JS share one list registered for `typescript`, `typescriptreact`, `javascript` and `javascriptreact`.
2. **Filetype from the path.** `vim.filetype.match({ filename = path })` is pure enough for unit tests and needs no buffer. A caller may pass the filetype it already knows.
3. **Rust inline tests** are a separate function with injected text, so `scope.lua` stays pure. The view supplies the text it already reads for the preview. Without a parser, `pcall` returns false and only the path rules apply. The config currently installs no `rust` parser (`lua/gleb/treesitter.lua`), so this is inactive until that parser is added.
4. **Project extension** through `vim.g.gleb_test_patterns`. It is appended after the built-ins and never replaces them.

## Risks / Trade-offs

- [A project keeps tests somewhere unconventional] → `vim.g.gleb_test_patterns`.
- [The generic `spec` segment flags a production folder named `spec` (e.g. OpenAPI specs)] → accepted: it matches what JetBrains users expect and is rare. A project can still override at the table level later.
