# Tasks

## 1. Drive Go classification through the real mapping
Scenarios: `references: gr classifies every Go variable usage`
- [x] 1.1 Write the test `references: gr classifies every Go variable usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on populated `Calls` data, assert every rendered usage kind, require missing servers or parsers to fail with their reason instead of skipping, and see it fail
- [x] 1.2 Replace the direct request/classifier helper with a reusable real-`gr` view helper while preserving the exact Go expectations
- [x] 1.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Go variable usage"` and see it pass

## 2. Merge Lua write highlights omitted from references
Scenarios: `references: gr classifies every Lua local usage`
- [x] 2.1 Write the test `references: gr classifies every Lua local usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on the populated Lua local and see it fail because the assignment target is absent
- [x] 2.2 Merge current-file non-origin write highlights into the reference usages before classification, deduplicating by URI and range
- [x] 2.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Lua local usage"` and see it pass

## 3. Exercise Python through the rendered view
Scenarios: `references: gr classifies every Python variable usage`
- [x] 3.1 Write the test `references: gr classifies every Python variable usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on populated Python data and see the old direct-classifier test path fail the new entry-point assertion
- [x] 3.2 Reuse the real-`gr` helper for basedpyright and assert the exact rendered write/read rows
- [x] 3.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Python variable usage"` and see it pass

## 4. Exercise TypeScript through the rendered view
Scenarios: `references: gr classifies every TypeScript variable usage`
- [x] 4.1 Write the test `references: gr classifies every TypeScript variable usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on populated TypeScript data and see the old direct-classifier test path fail the new entry-point assertion
- [x] 4.2 Reuse the real-`gr` helper for vtsls and assert the exact rendered write/read rows
- [x] 4.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every TypeScript variable usage"` and see it pass

## 5. Exercise Rust through the rendered view
Scenarios: `references: gr classifies every Rust variable usage`
- [x] 5.1 Write the test `references: gr classifies every Rust variable usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on populated Rust data and see the old direct-classifier test path fail the new entry-point assertion
- [x] 5.2 Reuse the real-`gr` helper for rust-analyzer and assert the exact rendered write/read rows
- [x] 5.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Rust variable usage"` and see it pass

## 6. Classify Bash variable reads
Scenarios: `references: gr classifies every Bash variable usage`, `references: Treesitter fallback classifies writes where a parser exists`
- [x] 6.1 Write the test `references: gr classifies every Bash variable usage` in `tests/integration/references/test_kind.lua` and tighten `references: Treesitter fallback classifies writes where a parser exists` in `tests/unit/references/test_kind_ts.lua`; press the real normal-mode `gr` on populated Bash data and see non-target variables remain `other`
- [x] 6.2 Make the treesitter fallback return `read` for matched variable uses that are not write targets, while callable-symbol handling still forces function usages to `other`; add the missing `tagged` and `has_kinds` LuaCATS annotations in `lua/gleb/references/tree.lua`
- [x] 6.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Bash variable usage"` and `make test FILE=tests/unit/references/test_kind_ts.lua CASE="Treesitter fallback classifies writes where a parser exists"`, and see both pass

## 7. Classify Terraform traversals through gr
Scenarios: `references: gr classifies every Terraform variable usage`
- [x] 7.1 Write the test `references: gr classifies every Terraform variable usage` in `tests/integration/references/test_kind.lua`; press the real normal-mode `gr` on the populated `tfproj` fixture and see its rows remain `other`
- [x] 7.2 Reuse the real-`gr` helper for terraform-ls and classify its listed `var.region` traversals as reads
- [x] 7.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Terraform variable usage"` and see it pass

## 8. Add HCL write/read syntax fallback
Scenarios: `references: HCL fallback classifies variable labels and traversals`
- [ ] 8.1 Write the test `references: HCL fallback classifies variable labels and traversals` in `tests/unit/references/test_kind_ts.lua` against populated HCL source and see both positions remain `other`
- [ ] 8.2 Add the HCL treesitter query that classifies a `variable` block label as `write` and `var.<name>` traversals as `read`, resolving Terraform filetypes to the HCL parser language
- [ ] 8.3 Run `make test FILE=tests/unit/references/test_kind_ts.lua CASE="HCL fallback classifies variable labels and traversals"` and see it pass

## Agent decisions

- The real-`gr` helper reads usage metadata from visible view nodes and verifies each node's label is rendered, preserving exact path, line, column and kind assertions without coupling to icons or indentation.
- The queued behavior requires non-target variable uses to become `read`, so the existing fallback scenario's conflicting `other` expectation is changed while its title, WHEN inputs, paths and numeric values remain intact.
- Write highlights join the request fan-out so the view receives one URI-and-range-deduplicated usage list before classification.
- The real-`gr` helper requires two consecutive populated reference responses so rust-analyzer has reached a stable indexed state without an arbitrary sleep.
- Unresolved terraform-ls references beginning at `var.` are reads because Terraform input variables are immutable and terraform-ls does not provide document-highlight kinds.
