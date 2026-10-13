## MODIFIED Requirements

### Requirement: Shortcut table
The chain SHALL route every shortcut in the shortcut table (section "Shortcut table" below) as listed, with zellij in `normal` mode and the focused zellij pane running Neovim in normal mode.

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
- **THEN** it matches the row's *Mapping* column

### Requirement: Real key presses in the sandbox VM deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance (repo config) running real zellij (user keybinds, the stack layer's layout), with key events posted to that process inside the sandbox macOS VM, never on the host. Exceptions: the app menu takes Cmd+Q and Cmd+H, and the key helper never presses Cmd+Shift+Q (system Log Out).

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut except Cmd+Q, Cmd+Shift+Q and Cmd+H is pressed in the Alacritty window
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim from a real key press
- **WHEN** a recorder mapping is set for the keys they encode and Cmd+J, Cmd+K, Cmd+[ and Cmd+] are pressed
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim as <C-CR> from a real key press
- **WHEN** recorders are set for `<C-CR>` and `<CR>` and Ctrl+Return is pressed
- **THEN** only the `<C-CR>` recorder fires

#### Scenario: Cmd+H never reaches Neovim from a real key press
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, a recorder is set for `<C-H>`, and Cmd+H is pressed
- **THEN** no recorder fires and the current Neovim window is still the right one

#### Scenario: Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press
- **WHEN** recorders are set for `<S-D-->`, `<S-D-=>`, `<M-_>` and `<M-+>` and Cmd+Shift+- then Cmd+Shift+= are pressed
- **THEN** exactly `<S-D-->` then `<S-D-=>` are recorded

#### Scenario: Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press
- **WHEN** a buffer with at least two top-level folds is open with all folds open, Cmd+Shift+- is pressed, then Cmd+Shift+= is pressed
- **THEN** after Cmd+Shift+- every top-level fold is closed (`foldclosed()` of each fold's first line is not -1), and after Cmd+Shift+= none is

#### Scenario: Ctrl+Up grows the current Neovim split from a real key press
- **WHEN** two Neovim windows exist stacked, the cursor is in the top one, and Ctrl+Up is pressed
- **THEN** the current window is 2 rows taller

#### Scenario: Cmd+L at the rightmost Neovim split moves zellij focus right from a real key press
- **WHEN** Neovim has one window and Cmd+L is pressed
- **THEN** zellij focus moves to the `cat` pane on the right

#### Scenario: Ctrl+H in a non-Neovim pane moves zellij focus left from a real key press
- **WHEN** the `cat` pane is focused and Ctrl+H is pressed
- **THEN** zellij focus moves to the Neovim pane on the left

#### Scenario: Ctrl+Q quits zellij and closes the Alacritty window
- **WHEN** Ctrl+Q is pressed
- **THEN** the zellij session ends and the Alacritty process exits

#### Scenario: Cmd+Q quits Alacritty from a real key press
- **WHEN** Cmd+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Cmd+Shift+Q is never pressed: the key helper refuses it
- **WHEN** `keys press <pid> cmd+shift+q` runs
- **THEN** it exits with status 2 and prints `keys press: refused, cmd+shift+q is a denied system-wide chord` without posting an event
