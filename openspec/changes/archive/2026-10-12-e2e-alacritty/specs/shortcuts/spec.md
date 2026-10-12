## REMOVED Requirements

### Requirement: Real Alacritty delivers shortcuts
**Reason**: The System Events gui layer is replaced by the e2e layer, which checks every row instead of four.
**Migration**: "Physical shortcuts reach their Neovim key in Alacritty" is covered by "Every passed shortcut reaches its Neovim key from a real key press" in "Real key presses in Alacritty deliver shortcuts".

## ADDED Requirements

### Requirement: Real key presses in Alacritty deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance started with the repo's Alacritty config and running real zellij with the user's keybinds and the stack layer's two-pane layout, with key events posted to that instance's process. Only this layer exercises Alacritty's own key encoding (rows with source `kitty`, `option_as_alt`, macOS key handling).

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut is pressed in the Alacritty window
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim from a real key press
- **WHEN** a recorder mapping is set for the keys they encode and Cmd+J, Cmd+K, Cmd+[ and Cmd+] are pressed
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim as <C-CR> from a real key press
- **WHEN** recorders are set for `<C-CR>` and `<CR>` and Ctrl+Return is pressed
- **THEN** only the `<C-CR>` recorder fires

#### Scenario: Cmd+H moves to the left Neovim split from a real key press
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, and Cmd+H is pressed
- **THEN** the current Neovim window is the left one and zellij focus stays on the Neovim pane

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
