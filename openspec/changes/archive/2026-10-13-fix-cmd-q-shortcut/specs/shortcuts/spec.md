# Spec Delta

## ADDED Requirements

### Requirement: The app menu leaves Cmd+Q and Cmd+H to the terminal
The repo SHALL provide an idempotent macOS setup step that moves Alacritty's app-menu key equivalents for "Quit alacritty" to Cmd+Option+Control+Q and "Hide alacritty" to Cmd+Option+Control+H in the `org.alacritty` defaults domain while keeping every other entry. The host SHALL apply it with a make target, and the sandbox VM SHALL apply it before e2e.

#### Scenario: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H
- **WHEN** the setup step runs against an empty defaults plist
- **THEN** its `NSUserKeyEquivalents` is exactly `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`

#### Scenario: Menu key setup is idempotent and keeps other entries
- **WHEN** the setup step runs twice against a defaults plist whose `NSUserKeyEquivalents` already holds `"Hide alacritty" = "@\Uf70f"` and `"Minimize" = "@m"`
- **THEN** `NSUserKeyEquivalents` is `"Quit alacritty" = "@~^q"`, `"Hide alacritty" = "@~^h"` and `"Minimize" = "@m"`, and the second run exits 0

## MODIFIED Requirements

### Requirement: Real key presses in the sandbox VM deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance with the repo config and app-menu setup, running real zellij with the stack layer's layout. Events SHALL be posted only inside the sandbox macOS VM. Cmd+Shift+Q is system-owned and SHALL never be pressed.

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut except Cmd+Shift+Q is pressed in the Alacritty window
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

#### Scenario: Cmd+H never reaches Neovim from a real key press
- **WHEN** the app-menu setup is deliberately absent, two Neovim windows exist side by side, the cursor is in the right one, a recorder is set for `<C-H>`, and Cmd+H is pressed in a fresh Alacritty window
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

#### Scenario: Cmd+Option+Control+Q quits Alacritty from a real key press
- **WHEN** Cmd+Option+Control+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Cmd+Q quits Alacritty from a real key press
- **WHEN** the app-menu setup is deliberately absent and Cmd+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Controlled no-setup regressions do not mutate when e2e cannot run
- **WHEN** the e2e preflight skips or fails before a controlled no-setup regression
- **THEN** no defaults command runs and no Alacritty instance starts

#### Scenario: Controlled no-setup regressions restore menu keys after lifecycle failures
- **WHEN** the fresh Alacritty instance fails to start or stop during a controlled no-setup regression
- **THEN** the versioned menu-key setup still runs before the failure is reported

#### Scenario: Cmd+Shift+Q is never pressed: the key helper refuses it
- **WHEN** `keys press <pid> cmd+shift+q` runs
- **THEN** it exits with status 2 and prints `keys press: refused, cmd+shift+q is a denied system-wide chord` without posting an event
