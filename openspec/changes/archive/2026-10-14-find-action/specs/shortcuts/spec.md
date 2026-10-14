# Spec Delta

## MODIFIED Requirements

### Requirement: Shortcut table
The chain SHALL route every shortcut in the shortcut table (section "Shortcut table" below) as listed, with zellij in `normal` mode and the focused zellij pane running Neovim in normal mode. Cmd+9 SHALL have no normal-mode mapping. Cmd+Shift+F SHALL invoke `require("gleb.picker").grep_live`. Cmd+Shift+A SHALL send `\eA`, pass through zellij, arrive as `<M-A>`, and invoke `require("gleb.find_action").open`.

#### Scenario: Alacritty bindings match the shortcut table
- **WHEN** the effective Alacritty bindings (imports followed) are parsed
- **THEN** every `chars` binding outside Vi mode has a `chars` row with the same bytes, every `chars` row has such a binding, and every `kitty` row's bytes equal Alacritty's kitty flag-1 encoding of the shortcut

#### Scenario: Every Alacritty chars binding can match a key press
- **WHEN** the effective Alacritty bindings (imports followed) are parsed
- **THEN** no `chars` binding outside Vi mode has `Shift` in its mods together with a non-letter character key (`Minus`, `Equals`, `Slash`, `LBracket`, `RBracket`, `Key0`–`Key9` and other punctuation keys), because Alacritty 0.17 matches the shifted character (`_`, `+`, ...) and such a binding never fires; each offending binding is reported with its key, mods and bytes

#### Scenario: zellij routes every shortcut as in the table
- **WHEN** the zellij keybinds are resolved for `normal` mode and each row's bytes are decoded the way zellij parses them
- **THEN** the route is the row's *zellij* column

#### Scenario: Locked mode passes every shortcut through
- **WHEN** the zellij keybinds are resolved for `locked` mode
- **THEN** every row's bytes are written to the pane unchanged

#### Scenario: Neovim receives the key in the table
- **WHEN** the bytes zellij writes to the Neovim pane for a row are decoded the way Neovim's TUI decodes them
- **THEN** the key is the row's *Neovim receives* column

#### Scenario: Neovim mappings match the table
- **WHEN** the full config is loaded, VeryLazy has fired, and `vim.fn.maparg(<received key>, "n", false, true)` is read for each row
- **THEN** it matches the row's *Mapping* column except that Cmd+9 has no mapping, including Cmd+Shift+F invoking `require("gleb.picker").grep_live` and Cmd+Shift+A invoking `require("gleb.find_action").open`

## ADDED Requirements

### Requirement: Find Action shortcut delivery
Cmd+Shift+A SHALL open Find Action through a real zellij stack and from a real macOS key press in the sandbox VM.

#### Scenario: Cmd+Shift+A opens Find Action through real zellij
- **WHEN** Cmd+Shift+A bytes are sent through the real zellij stack to Neovim
- **THEN** the Find Action palette opens

#### Scenario: Cmd+Shift+A opens Find Action from a real key press
- **WHEN** Cmd+Shift+A is posted to the sandbox Alacritty process as a real macOS key press
- **THEN** the Find Action palette opens in Neovim
