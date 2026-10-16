## ADDED Requirements

### Requirement: Read/write grouping
When at least one listed usage is classified `write` or `read`, the tree SHALL add a read/write level between test scope and folder, with groups `Value write` (pencil, blue), `Value read` (eye, yellow) and `Usage` (other) in that order, each with its count and a label in the paler shade of its icon colour. When no usage is `write` or `read`, the level and its hint SHALL be omitted.

#### Scenario: Variable usages are grouped by write and read
- **WHEN** `gr` is pressed on the `Calls` declaration in `report/calls.go` of the extended `gomod` fixture with gopls attached, the editor at 100x30 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed K1 — read/write level"

#### Scenario: Function usages have no read/write level or hint
- **WHEN** the view is open for `Format` in the `gomod` fixture and classification has finished
- **THEN** no `Value write`, `Value read` or `Usage` rows exist, the hint row has no `Read/write` entry, and the screen still matches "Proposed V1 — default grouping"

### Requirement: Read/write toggle
When the read/write level is available, `w` SHALL toggle it, the hint row SHALL show `●`/`○ Read/write w`, and the state SHALL persist across sessions. With the level off, each classified usage row SHALL carry a right-aligned `write` (pencil, blue) or `read` (eye, yellow) tag.

#### Scenario: w turns the level into row tags
- **WHEN** the view is open for `Calls` with default grouping after classification and `w` is pressed
- **THEN** the screen matches the approved render "Proposed K2 — read/write level off"

#### Scenario: Read/write state persists across sessions
- **WHEN** `w` is pressed in the view for `Calls`, Neovim is restarted, and the view is opened again for `Calls`
- **THEN** the hint row shows `○ Read/write w` and no `Value write` or `Value read` rows exist

#### Scenario: The read/write key comes from the keymap file
- **WHEN** the view buffer is current and its buffer-local normal-mode mapping for `w` is read
- **THEN** its `desc` names the registered `references.toggle_read_write` action and `settings/keymap.json` lists that action with `w`

### Requirement: Usage kind classification
Each usage SHALL be classified `write`, `read` or `other`. For vtsls, kinds SHALL come from tsserver's references response (`isWriteAccess`). For other clients that support `textDocument/documentHighlight`, kinds SHALL come from one highlight request per file, matched to usages by range. A usage still unclassified SHALL use the treesitter fallback when the file's parser is installed, else be `other`.

#### Scenario: gopls kinds classify a Go variable
- **WHEN** usages of `Calls` in the extended `gomod` fixture are classified with gopls attached
- **THEN** `report/calls.go:8` and `report/calls_test.go:6` are `write`, and `report/calls_test.go:8` and `:9` are `read`

#### Scenario: lua_ls kinds classify a Lua local
- **WHEN** usages of `count` are classified in a temporary Lua file `local count = 0` / `count = count + 1` / `print(count)` with lua_ls attached
- **THEN** the usage on line 2 at column 1 is `write`, and the usages on line 2 after `=` and on line 3 are `read`

#### Scenario: basedpyright kinds classify a Python variable
- **WHEN** usages of `total` are classified in a temporary Python module `total = 0` / `total += 1` / `print(total)` with basedpyright attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: tsserver kinds classify a TypeScript variable
- **WHEN** usages of `hits` are classified in a temporary TypeScript project `let hits = 0;` / `hits++;` / `console.log(hits);` with vtsls attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: rust-analyzer kinds classify a Rust variable
- **WHEN** usages of `n` are classified in a temporary Cargo crate whose `main` has `let mut n = 0;` / `n += 1;` / `println!("{n}");` with rust-analyzer attached
- **THEN** the usage on line 2 is `write` and the usage on line 3 is `read`

#### Scenario: Treesitter fallback classifies writes where a parser exists
- **WHEN** the treesitter fallback classifies the target identifier in `x := 1` and `x++` (Go), `x = 1` (Lua), `x=1` (Bash), and `print(x)` / `echo "$x"` in each
- **THEN** every assignment, declaration and increment target is `write` and every argument is `other`

#### Scenario: Without kinds or a parser a usage is other
- **WHEN** a usage is classified for a file whose client offers no kinds and whose filetype has no installed parser
- **THEN** no error is raised and the usage is `other`

### Requirement: Asynchronous classification
The view SHALL open with scope and folder grouping as soon as references arrive, show `Usages of <symbol> · <count> · classifying` in its title while classification runs (at most 3 seconds), and rebuild with the read/write level when it finishes, keeping the selected usage.

#### Scenario: The view opens before classification finishes
- **WHEN** `gr` is pressed on `Calls` with documentHighlight responses delayed by a test hook
- **THEN** the view is open with title `Usages of Calls · 4 · classifying` and no read/write rows, and after the responses arrive the title is `Usages of Calls · 4` with read/write rows and the same selected usage

#### Scenario: Classification gives up after the timeout
- **WHEN** documentHighlight never answers for a file
- **THEN** after 3 seconds the title drops `· classifying`, the remaining usages are classified by the fallback, and nothing is reported as an error
