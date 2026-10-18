## ADDED Requirements

### Requirement: Picker input prompt
`require("gleb.picker.input").open({ title, default?, preview, hint, on_submit })` SHALL show the shared frame with `<title> › <query>` in its top border, one live `preview(query)` row, and `hint` right-aligned below the joined rule. The query SHALL start as `default`. `<CR>` on a non-blank query SHALL close and schedule `on_submit(trimmed_query)` after picker teardown. `<Esc>` SHALL close without submitting and restore origin focus and cursor state.

#### Scenario: Input prompt submits its query
- **WHEN** an input prompt titled `New File or Directory` is open and `fee.go<CR>` is typed
- **THEN** no picker is active and `on_submit` was called once with `fee.go`

#### Scenario: Input prompt starts with its default and previews it
- **WHEN** an input prompt opens with `default = "invoice.go"` and a `preview` that returns `{ text = "internal/billing/" .. query }`
- **THEN** the query is `invoice.go`, the only row reads `internal/billing/invoice.go`, and after typing `x` it reads `internal/billing/invoice.gox`

#### Scenario: Input prompt cancels with Esc
- **WHEN** an input prompt is open, `fee.go` is typed and `<Esc>` is pressed
- **THEN** no picker is active and `on_submit` was never called

#### Scenario: Input prompt ignores a blank query
- **WHEN** an input prompt is open with an empty query and `<CR>` is pressed
- **THEN** the prompt stays open and `on_submit` was never called

#### Scenario: Input prompt Esc restores tree focus and cursor state
- **WHEN** a project tree with its cursor hidden opens an input prompt, `<Esc>` is pressed, and picker teardown completes
- **THEN** the project tree is current, no picker is active, and `guicursor` equals the tree's captured hidden-cursor value

#### Scenario: Input prompt submits after the picker closes
- **WHEN** an input prompt's `on_submit` records whether a picker is active and `fee.go<CR>` is typed
- **THEN** `on_submit` runs once on the scheduled main loop with no picker active
