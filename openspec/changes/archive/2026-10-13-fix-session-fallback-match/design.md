## Context
See proposal.md - Why. Root cause: `key.resolve` (`lua/gleb/session/key.lua`) tests the fallback with `vim.endswith(candidate, slug)`, which is true for any name whose tail happens to equal the slug, including slugs of deeper paths (`%baz%foo%bar` ends with `%foo%bar`). The "most recent" ordering lives in resession's `list()`, which sorts by the session file's `mtime.sec` only because its default `load_order` is `"modification_time"`; `lua/gleb/session/init.lua` does not pin it.

No visible UI: nothing on screen changes, so no renders.

## Goals / Non-Goals
**Goals:**
- The fallback accepts a name only when it parses as `<zellij session>-<pane id>-<cwd slug>` with the full current slug.
- The newest-first order is an explicit, tested part of this config.

**Non-Goals:**
- Sorting candidates ourselves; resession's `list()` stays the source of order.
- Matching sessions saved by other naming schemes (none exist in this config).

## Decisions
- **Split by plain suffix, then match the head with a pattern.** Strip the plain suffix `"-" .. slug` (string compare, no pattern), then require the remaining head to match `^[^%%]+%-%d+$`. Alternative: one Lua pattern built from `vim.pesc(slug)`; rejected as harder to read and easy to get wrong with `%`, `-` and `.` in slugs. The "no `%` in the zellij part" rule is what rejects `x-9-%baz` (from cwd `/baz-1/foo/bar`) when the slug contains `-<digits>-`; zellij session names never contain `/`, `\` or `:`, so a real zellij part never holds `%`. Dashes inside the zellij name (`my-proj`) still match because `[^%]+` spans them.
- **Pin `load_order = "modification_time"` in `resession.setup`.** Alternative: sort by mtime in `restore()`; rejected (duplicates plugin behaviour, rule of preferring plugin options over custom code).
- **Small named helper** (e.g. `is_cwd_session(candidate, slug)`) used by `resolve`, keeping `resolve` a short loop.

## Risks / Trade-offs
- [resession compares `mtime.sec`, so two saves in the same second tie and order is unspecified] → the integration test sets file mtimes at least several seconds apart with `vim.uv.fs_utime`; same-second ties in real use are harmless (both are equally recent).
- [Old session files saved under a deeper path stop restoring from the parent cwd] → intended; that was the bug.

## Migration Plan
None; existing session files keep their names. Rollback is reverting the commit.
