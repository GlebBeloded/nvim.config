## ADDED Requirements

### Requirement: The app menu leaves Cmd+Q and Cmd+H to the terminal
The repo SHALL provide an idempotent macOS setup step that moves Alacritty's app-menu key equivalents for "Quit alacritty" to Cmd+Option+Control+Q and "Hide alacritty" to Cmd+Option+Control+H in the `org.alacritty` defaults domain, keeping every other entry of that domain. The host applies it with a make target; the sandbox VM is provisioned with it.

#### Scenario: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H
- **WHEN** the setup step runs against an empty defaults plist
- **THEN** its `NSUserKeyEquivalents` is exactly `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`

#### Scenario: Menu key setup is idempotent and keeps other entries
- **WHEN** the setup step runs twice against a defaults plist whose `NSUserKeyEquivalents` already holds `"Hide alacritty" = "@\Uf70f"` and `"Minimize" = "@m"`
- **THEN** `NSUserKeyEquivalents` is `"Quit alacritty" = "@~^q"`, `"Hide alacritty" = "@~^h"` and `"Minimize" = "@m"`, and the second run exits 0

### Requirement: Real key presses in the provisioned sandbox VM deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance (repo config, app-menu setup applied) running real zellij (user keybinds, the stack layer's layout), with key events posted to that process inside the sandbox macOS VM, never on the host. Exceptions: Cmd+Shift+-/= arrive in Alacritty's kitty encoding; Cmd+Shift+Q (system Log Out) is never pressed.

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut except Cmd+Shift+Q, Cmd+Shift+- and Cmd+Shift+= is pressed in the Alacritty window
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim from a real key press
- **WHEN** a recorder mapping is set for the keys they encode and Cmd+J, Cmd+K, Cmd+[ and Cmd+] are pressed
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim as <C-CR> from a real key press
- **WHEN** recorders are set for `<C-CR>` and `<CR>` and Ctrl+Return is pressed
- **THEN** only the `<C-CR>` recorder fires

#### Scenario: Cmd+Q reaches Neovim as <M-q> from a real key press
- **WHEN** a recorder is set for `<M-q>` and Cmd+Q is pressed
- **THEN** exactly `<M-q>` is recorded and the Alacritty process is still running with its window visible

#### Scenario: Cmd+H moves to the left Neovim split from a real key press
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, and Cmd+H is pressed
- **THEN** the current Neovim window is the left one, zellij focus stays on the Neovim pane and the Alacritty window is visible

#### Scenario: Cmd+H in a non-Neovim pane moves zellij focus left from a real key press
- **WHEN** the `cat` pane is focused and Cmd+H is pressed
- **THEN** zellij focus moves to the Neovim pane on the left

#### Scenario: Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press
- **WHEN** recorders are set for `<S-D-->`, `<S-D-=>`, `<M-_>` and `<M-+>` and Cmd+Shift+- then Cmd+Shift+= are pressed
- **THEN** exactly `<S-D-->` then `<S-D-=>` are recorded

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

#### Scenario: Cmd+Option+Control+Q quits Alacritty from a real key press
- **WHEN** Cmd+Option+Control+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Cmd+Shift+Q is never pressed: the key helper refuses it
- **WHEN** `keys press <pid> cmd+shift+q` runs
- **THEN** it exits with status 2 and prints `keys press: refused, cmd+shift+q is a denied system-wide chord` without posting an event

## REMOVED Requirements

### Requirement: Real key presses in the sandbox VM deliver shortcuts
**Reason**: The app menu no longer takes Cmd+Q and Cmd+H once the menu key setup is applied, so its scenarios "Cmd+H never reaches Neovim from a real key press" and "Cmd+Q quits Alacritty from a real key press" describe behaviour that is gone.
**Migration**: Replaced by "Real key presses in the provisioned sandbox VM deliver shortcuts"; quitting Alacritty from the keyboard moves to Cmd+Option+Control+Q, hiding it to Cmd+Option+Control+H.
