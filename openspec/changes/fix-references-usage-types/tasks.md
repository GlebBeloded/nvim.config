## 1. Catalogue and query runner

Scenarios: `references: Every query capture is in the catalogue`, `references: Go types carry GoLand labels`, `references: Treesitter fallback classifies writes where a parser exists`, `references: HCL fallback classifies variable labels and traversals`, `references: Without kinds or a parser a usage is other`

- [x] 1.1 Write the scenarios in tests/unit/references/test_usage_types.lua and adapt tests/unit/references/test_kind_ts.lua to the query runner, and see them fail
- [x] 1.2 Add `lua/gleb/references/usage_types.lua`: the typed catalogue from design.md (Catalogue), with `label`, `icon`, `colour`, `tag` and `order` by label.
- [x] 1.3 Move the inline queries from `kind_ts.lua` into `queries/{lua,bash,hcl}/usages.scm` as `@usage.write`/`@usage.read`, and add `queries/terraform/usages.scm` (`; inherits: hcl`).
- [x] 1.4 Make `kind_ts.lua` the generic runner (design Decisions 1 and 4).
- [x] 1.5 Run `make test FILE=tests/unit/references/test_usage_types.lua` and `make test FILE=tests/unit/references/test_kind_ts.lua` and see them pass

## Agent decisions

- The catalogue exports entries keyed directly by usage id so query validation and later consumers use the same lookup.
- `unclassified` has an empty tag because unclassified rows do not display a type tag.
- A minimal Go fallback query preserves the existing Go scenario until task 2 replaces it with the full Go catalogue query.

## 2. Go query and target kind

Scenarios: `references: Go query classifies every GoLand usage type`, `references: A Go conversion of a type is a type conversion`, `references: A function passed as a value is a function argument`, `references: A variable named by a type identifier is a type target`, `references: Terraform blocks are not type targets`, `references: Function and type targets get no write or read`

- [x] 2.1 Port the Go entries of `drafts/cases.lua` into tests/unit/references/test_go_usages.lua (real `go` parser), add the target-kind cases, and see them fail
- [x] 2.2 Add `queries/go/usages.scm` from `drafts/queries/go/usages.scm`, renaming `value_write` to `write` (regenerate with `drafts/gen_go.py` or hand-maintain; every draft case must pass).
- [x] 2.3 Generalise `request_callable` in `kind.lua` to `request_target_kind` and apply the refinement rules, including the `type_identifier` upgrade (design Decision 3).
- [x] 2.4 Run the unit files and see them pass

## 3. Classification order through gr

Scenarios: `references: gr classifies struct usages`, `references: gr classifies function usages as calls`, `references: Composite literal keys are field writes`, `references: gopls kinds classify a Go variable`, `references: gr classifies every Go variable usage`, `references: gr classifies every Lua local usage`, `references: gr classifies every Bash variable usage`, `references: gr classifies every Terraform variable usage`, `references: Classification gives up after the timeout`

- [ ] 3.1 Extend the `gomod` fixture in tests/fixtures/build.sh with `billing/batch.go` and `billing/invoice_test.go` (design Decision 8, exact text as in the T1 preview) and the `Invoice` manifest entry. Write the three new scenarios in tests/integration/references/test_kind.lua. See them fail.
- [ ] 3.2 Implement the order in `kind.lua` (design Decision 2): `other` becomes `unclassified`, and the query step needs no server.
- [ ] 3.3 Run `make test FILE=tests/integration/references/test_kind.lua` and see every scenario in it pass, the old ones included

## 4. Tree level, icons, toggle and state

Scenarios: `references: Unclassified usages add no level`, `references: Usage type groups sort by label`, `references: Usage type icons and label shades match the palette`, `references: A saved read/write state carries over`, `references: The usage type key comes from the keymap file`, `references: View keys come from the keymap file`, `references: Usage type state persists across sessions`, `references: Go usages are grouped by scope and folder`, `references: Function usages are grouped under Call`, `references: The view opens before classification finishes`

- [ ] 4.1 Write the scenarios in tests/unit/references/test_tree.lua, tests/integration/references/test_icons.lua, test_keys.lua and test_kind_view.lua. Delete the cases of the removed scenarios: `Function usages have no read/write level or hint`, `w turns the level into row tags`, `Read/write state persists across sessions`, `The read/write key comes from the keymap file`. See the new ones fail.
- [ ] 4.2 Add:
  - the `type` level in `tree.lua` (design Decision 5);
  - per-type icon and label groups in `icons.lua` (Decision 7);
  - `references.toggle_usage_type` in `actions.lua` and `view.lua`, bound to `u` in `settings/keymap.json`, with `references.toggle_read_write` removed;
  - `usage_type` with the legacy migration in `state.lua`;
  - row tags with left-shortened paths.
- [ ] 4.3 Run the four files and see them pass

## 5. Screens and the real-key workflow

Scenarios: `references: Wide view matches reference screenshot`, `references: Narrow view fits its content`, `references: Tests key cycles grouped, hidden and mixed`, `references: Mixed tests without folders is a flat list`, `references: Variable usages are grouped by write and read`, `references: Struct usages are grouped by usage type`, `references: u turns the level into row tags`, `references: u turns struct usage types into row tags`, `references: Real key presses switch Calls usages from the level to row tags`

- [ ] 5.1 Update tests/screen/references/test_view.lua and its screenshots to Proposed V1–V4, K1, K2, T1 and T2 (real glyphs where the render has stand-ins; attribute blocks per the mask groups), and see them fail
- [ ] 5.2 Update the e2e Calls test to press `u`, and compare each step's zellij dump with K1/K2
- [ ] 5.3 Make `make test-screen` and `make e2e` (sandbox VM) pass, then `make check`. Compare `make render` with `renders/*.ansi`.
- [ ] 5.4 Update `references` in the module map of `docs/architecture.md`: the usage type catalogue and the `queries/<lang>/usages.scm` convention
