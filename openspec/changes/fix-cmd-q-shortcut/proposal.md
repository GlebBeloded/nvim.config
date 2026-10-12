## Why
The shortcut table lists Cmd+Q → `\eq` → `<M-q>` and Cmd+Shift+Q → `\eQ` → `<M-Q>` (Alacritty `chars` bindings in `terminal/alacritty/keymaps_macos.toml`), but neither reaches Neovim from a real key press (e2e layer in the sandbox VM): Cmd+Q is the macOS app menu's Quit and closes Alacritty with every zellij pane in it, and Cmd+Shift+Q is the system Log Out shortcut, taken before Alacritty sees it. One stray Cmd+Q loses the whole terminal session. The same app menu takes Cmd+H (Hide Alacritty), so the core split/pane navigation key Cmd+H (`\x08` → `<C-H>`) never reaches zellij or Neovim either.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.
Open question for the user: what should Cmd+Q, Cmd+H and Cmd+Shift+Q do? (Cmd+H most likely as A: navigate.)
- A: Cmd+Q reaches Neovim as `<M-q>`: the existing `chars = "\u001Bq"` binding loses to the menu item, so this needs the menu's key equivalent moved (e.g. `defaults write org.alacritty NSUserKeyEquivalents -dict-add "Quit Alacritty" "@~^q"`, likewise "Hide Alacritty"), which lives outside the repo; the sandbox VM would provision the same defaults.
- B: Cmd+Q does nothing (menu key equivalent moved as in A, binding removed); quitting stays on the menu.
- C: keep quitting, drop the dead `chars` rows (`\eq`, `\eQ`) from the Alacritty config and the shortcut table.
Cmd+Shift+Q cannot be taken back from the system short of remapping Log Out in System Settings > Keyboard > Shortcuts; any option drops its row or marks it unreachable.

## What Changes
- Depending on the chosen option: the Alacritty Cmd+Q / Cmd+H / Cmd+Shift+Q bindings or the menu key equivalents, the shortcut table rows, and the e2e scenarios "Cmd+Q quits Alacritty from a real key press" and "Cmd+H never reaches Neovim from a real key press".

## Capabilities
### Modified Capabilities
- `shortcuts`: shortcut table rows Cmd+Q, Cmd+H and Cmd+Shift+Q; requirement "Real key presses in the sandbox VM deliver shortcuts".

## Impact
- Code: `terminal/alacritty/keymaps_macos.toml`, possibly a macOS `defaults` step documented in docs/testing.md and provisioned in the sandbox VM.
- Plugins: none added, removed or upgraded.
- Core keymaps: changed (Cmd+Q / Cmd+H behaviour), user decides.
- Out of scope: other Cmd shortcuts that produce no bytes (Cmd+M/N/T/V/0, Cmd+Ctrl+F, Cmd+Shift+/, Cmd+`).

## Decision (user, 2026-10-12)
Option A: Cmd+Q, Cmd+H (and Cmd+Shift+Q where possible) reach Neovim. Move Alacritty's app-menu key equivalents for Quit and Hide off Cmd+Q / Cmd+H (`defaults write org.alacritty NSUserKeyEquivalents`), as a versioned, idempotent setup step in the repo (terminal/), applied on the host by a make target and provisioned in the sandbox VM. Prove with e2e scenarios that Cmd+Q arrives as `<M-q>` and Cmd+H navigates splits/panes. Cmd+Shift+Q (system Log Out) is never pressed by tests; mark its row unreachable unless remapped in System Settings.
