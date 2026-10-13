## Context

See proposal.md - Why. Root causes (pinned plugins, checked 2026-10-13):

- **lazy**: `lazy/health.lua:132` checks hererocks/luarocks only when `rocks.enabled` (default `true`). No plugin uses `build = "rockspec"`.
- **neo-tree**: `setup/init.lua` runs `merge_renderers(default, source_default, user)` only for sources in `config.sources`; `buffers` is not one, so `config.buffers.renderers` stays `nil`. `health/init.lua:302` validates `buffers` unconditionally → false positive. Our config is otherwise valid.
- **neotest-golang**: `health.lua:169-177` loads `features/testify/queries/go/{namespace,test_method}.scm`; the plugin ships `suite.scm`, `testify_method.scm`, ... The plugin's health check is stale; testify detection itself works.

No visible UI change: only `:checkhealth` output and `make smoke` results.

## Goals / Non-Goals

**Goals:** `make smoke-health` runs the `lazy` and `neo-tree` checks without exclude or ignore pattern and reports no ERROR; the remaining `neotest-golang` exclude is justified by an upstream link.

**Non-Goals:** enabling the neo-tree `buffers` source; patching plugin code; external-tool checks (proposal, Out of scope).

## Decisions

1. **lazy: `rocks = { enabled = false }`** in `lua/gleb/plugins/init.lua`. Alternative: keep the `HEALTH_IGNORE` pattern - hides a real config signal. `HEALTH_IGNORE` becomes empty; keep the mechanism (empty table) only if still referenced, otherwise remove it with `ignored()`.
2. **neo-tree: `buffers = { renderers = {} }`** in `file_tree/init.lua`, with a comment naming the health check. Upgrade rejected: latest `v3.x` (`1a14083`, 3.42.0, 2026-09-01) still validates `buffers` regardless of `sources`; no upstream issue/PR. An empty table passes `schema.Renderers` and is harmless if `buffers` is ever enabled (`merge_renderers` fills missing renderer names into it). Alternatives: copy the default renderers (more code for an unloaded source); add `"buffers"` to `sources` (changes the `>` source cycle, out of scope).
3. **neotest-golang: keep excluded, documented.** Latest main (`65b2be6`, v2.10.0, 2026-08-06) still loads `namespace.scm`/`test_method.scm`; PR #563 (v2.9.0) renamed the queries without updating `health.lua`. No upstream issue/PR exists. Upgrading does not fix it; patching the plugin or disabling testify would trade a real feature for a green check. The `HEALTH_EXCLUDE` entry gets a comment: stale testify query paths in upstream `health.lua` since https://github.com/fredrikaverpil/neotest-golang/pull/563; remove when upstream fixes it. Filing the upstream issue is outside the loop (never push / publish).
4. **`HEALTH_EXCLUDE` comment** lists external-tool checks plus the documented neotest-golang upstream bug; it no longer points at this change.

## Risks / Trade-offs

- [neotest-golang exclude hides future config regressions] → comment carries the upstream link; re-check on each `make update`.
- [Empty `buffers.renderers` masks a future real buffers misconfig] → only relevant if `buffers` joins `sources`, which is out of scope and would revisit this.

## Migration Plan

No plugin pin changes. One commit per task; rollback = revert.
