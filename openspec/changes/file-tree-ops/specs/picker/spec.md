## ADDED Requirements

### Requirement: Picker input prompt
`require("gleb.picker.input").open({ title, default?, preview, hint, on_submit })` SHALL show the shared picker frame with `<title> › <query>` in the top border, one row from `preview(query)` updated on every query change, and `hint` right-aligned below the joined rule. The query SHALL start as `default`. `<CR>` with a non-blank query SHALL close the prompt and call `on_submit` with the trimmed query; `<Esc>` SHALL close it without a call.

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
