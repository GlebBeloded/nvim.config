## MODIFIED Requirements

### Requirement: Real zellij delivers shortcuts
The stack SHALL behave as the shortcut table when real zellij 0.45 runs the user's keybinds (session serialization off, fixed two-pane layout: Neovim with the real config on the left, `cat` on the right) inside a tmux pty and the rows' bytes are written with `tmux send-keys -H`. The harness SHALL read zellij state through `zellij action` calls that retry zellij's transient CLI failures (`There is no active session!`, or `list-clients` with no client row) until a valid answer or a bounded deadline, so a case fails only when the session or its client is really gone.

#### Scenario: Every passed shortcut reaches its Neovim key through zellij
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and the row's bytes are sent
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim
- **WHEN** a recorder mapping is set for the key that was sent and the bytes of Cmd+J, Cmd+K, Cmd+[ and Cmd+] are sent
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim through the kitty keyboard protocol
- **WHEN** Neovim has negotiated the kitty keyboard protocol with zellij (Neovim queries `CSI ? u`, zellij answers) and `\e[13;5u` is sent
- **THEN** Neovim receives `<C-CR>`, not `<CR>` (zellij would downgrade it for a non-kitty pane)

#### Scenario: Cmd+H moves to the left Neovim split
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, and `\x08` is sent
- **THEN** the current Neovim window is the left one and zellij focus stays on the Neovim pane

#### Scenario: Cmd+Shift+J moves to the Neovim split below
- **WHEN** two Neovim windows exist stacked, the cursor is in the top one, and `\eJ` is sent
- **THEN** the current Neovim window is the bottom one (the navigator rewrites resize to `<M-j>`)

#### Scenario: Cmd+L at the rightmost Neovim split moves zellij focus right
- **WHEN** Neovim has one window and `\x0c` is sent
- **THEN** zellij focus moves to the `cat` pane on the right

#### Scenario: Cmd+H in a non-Neovim pane moves zellij focus left
- **WHEN** the `cat` pane is focused and `\x08` is sent
- **THEN** zellij focus moves to the Neovim pane on the left

#### Scenario: The stack harness retries a transient zellij CLI failure
- **WHEN** `focused_pane()` of a `tests.shortcuts.stack` Stack is called with `zellij` stubbed on `PATH` so that `action list-clients` first exits 1 printing `There is no active session!`, then exits 0 with only the header line, then prints a client row on `terminal_0`
- **THEN** it returns `terminal_0` and the stub was called 3 times

#### Scenario: The stack harness fails when the zellij session stays gone
- **WHEN** `focused_pane()` is called with `zellij` stubbed on `PATH` so that every `action list-clients` exits 1 printing `There is no active session!`
- **THEN** it raises an error containing `There is no active session!` within the harness deadline
