## MODIFIED Requirements

### Requirement: File tree nesting settings
`settings/file_tree.json` SHALL hold `nesting.enabled` and the ordered list `nesting.rules`. A pattern rule's `parent` and `children` SHALL be Lua patterns matched against a whole file name. A child template's `${capture}` (first capture) and `${1}`…`${9}` SHALL insert the parent's captures literally. A rule with a malformed pattern or an unknown capture SHALL be skipped with a WARN. An unreadable file SHALL disable nesting with an ERROR, and a write from Neovim SHALL reload it.

#### Scenario: Nesting rule nests by capture
- **WHEN** `require("gleb.tree.nesting").nest(dir, entries, rules)` gets the files `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `invoice_mock.go`, `tax.go` and the one rule `{ parent = "(.+)%.go", children = { "${capture}_test%.go", "${capture}_mock%.go" } }`
- **THEN** it returns exactly `{ ["discount.go"] = { "discount_test.go" }, ["invoice.go"] = { "invoice_mock.go", "invoice_test.go" } }`

#### Scenario: Nesting patterns match whole names
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `go.sum.bak`, `xgo.mod` and the rule `{ parent = "go%.mod", children = { "go%.sum" } }`
- **THEN** it returns exactly `{ ["go.mod"] = { "go.sum" } }`

#### Scenario: Nesting captures are inserted literally
- **WHEN** `nest` gets the files `a.b.ts`, `a.b.test.ts`, `aXb.test.ts` and the rule `{ parent = "(.+)%.ts", children = { "${capture}%.test%.ts" } }`
- **THEN** it returns exactly `{ ["a.b.ts"] = { "a.b.test.ts" } }`

#### Scenario: Broken nesting rules are skipped
- **WHEN** `nest` gets the files `go.mod`, `go.sum`, `init.lua`, `init_spec.lua` and the rules `{ parent = "go%.mod", children = { "${capture}%.sum" } }`, `{ parent = "[", children = { "x" } }`, `{ parent = "(.+)%.lua", children = { "${capture}_spec%.lua" } }`
- **THEN** it returns exactly `{ ["init.lua"] = { "init_spec.lua" } }`, and WARN notifications starting `File tree nesting rule 1 skipped` and `File tree nesting rule 2 skipped` are shown, once each per load

#### Scenario: Invalid settings file disables nesting
- **WHEN** the settings path holds `{ "nesting": ` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** an ERROR notification starting `File tree settings invalid` is shown, and `discount.go`, `discount_test.go`, `invoice.go`, `invoice_test.go`, `tax.go`, `tax_test.go` are sibling rows without a file chevron

#### Scenario: Writing the settings file reloads nesting
- **WHEN** the tree is open on the `treeproj` fixture with `internal/billing` expanded, the settings path (a temporary copy of the default file) is edited in a buffer to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

#### Scenario: Nesting can be turned off
- **WHEN** the settings file sets `nesting.enabled` to `false` and the tree opens on the `treeproj` fixture with `internal/billing` expanded
- **THEN** the six Go files of `internal/billing` are sibling rows in name order, and no file row has a chevron

#### Scenario: Writing settings through a normalized path reloads nesting
- **WHEN** `settings.setup` receives a settings path under `/var`, the same file is edited through its normalized `/private/var` path to remove the `(.+)%.go` rule, and `:write` is run
- **THEN** within 1 s `invoice_test.go` is a sibling row of `invoice.go`, and `invoice.go` has no chevron

### Requirement: Shared porcelain status records
`gleb.git.status.parse_records(z)` SHALL parse every porcelain-v2 NUL record once into ordered `{ kind, xy, sub, path, orig }` values. A `2` record SHALL consume its following original-path field. `gleb.git.status.parse(z, prefix)` and the ignored-path set SHALL remain wrappers over those records, and the Changes panel SHALL consume only those records.

#### Scenario: Shared parser preserves rename and copy origins
- **WHEN** `gleb.git.status.parse_records` receives NUL-delimited `2` records for a rename and a copy
- **THEN** each result has kind `2`, its XY and submodule fields, the destination in `path`, and the following NUL field in `orig`

#### Scenario: Shared parser classifies added and unmerged records
- **WHEN** `gleb.git.status.parse` receives an ordinary `.A` record and a `u` record
- **THEN** the ordinary path is `added`, the unmerged path is `conflict`, and neither record is ignored

#### Scenario: Shared parser keeps ignored records separate
- **WHEN** `gleb.git.status.parse` receives a modified tracked record, an untracked record and an ignored record
- **THEN** the status map contains the modified and untracked paths while the ignored set alone contains the ignored path
