# shortcuts Specification

## Purpose
The user-facing contract "physical shortcut → intended action" for the whole key path Alacritty → zellij → Neovim on macOS (Alacritty 0.17, zellij 0.45, Neovim 0.12). Alacritty `[[keyboard.bindings]]` with `chars` turn Command shortcuts into byte sequences, zellij (`keybinds clear-defaults=true`, default mode `normal`) may consume a key or hand it to the vim-zellij-navigator plugin, and Neovim maps what arrives. The Alacritty and zellij configs are external and unversioned; they are read from `$ALACRITTY_CONFIG_DIR` / `$ZELLIJ_CONFIG_DIR`, else `<repo>/terminal/<tool>`, else `~/.config/<tool>`. This spec describes current behaviour, including collisions.

Unlike other capabilities, these scenarios are not verified in a headless child Neovim alone. They run in three layers (docs/testing.md): **chain** (static: parse the real configs, route keys, check maparg in a child Neovim), **stack** (real zellij with the user's keybinds in a tmux pty, real Neovim config, bytes fed with `tmux send-keys -H`) and **e2e** (a dedicated real Alacritty instance with the repo's config, real macOS key events posted to its process; skipped without Accessibility permission).

## Requirements

### Requirement: Shortcut table
The chain SHALL route every shortcut in the shortcut table (section "Shortcut table" below) as listed, with zellij in `normal` mode and the focused zellij pane running Neovim in normal mode.

#### Scenario: Alacritty bindings match the shortcut table
- **WHEN** the effective Alacritty bindings (imports followed) are parsed
- **THEN** every `chars` binding outside Vi mode has a `chars` row with the same bytes, every `chars` row has such a binding, and every `kitty` row's bytes equal Alacritty's kitty flag-1 encoding of the shortcut

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

### Requirement: Collisions
The chain SHALL have exactly the zellij `normal`-mode bindings in the collision table (section "Collision table" below) shadowing a global Neovim mapping (any mode): keys zellij consumes, and navigator keys whose written bytes differ from the key that was sent.

#### Scenario: Collision report matches the collision table
- **WHEN** every `normal`-mode zellij binding is decoded to Neovim key notation and looked up with `maparg` in modes `n x s o i c t` of the full config
- **THEN** the shadowed keys are exactly the collision table

### Requirement: Real zellij delivers shortcuts
The stack SHALL behave as the shortcut table when real zellij 0.45 runs the user's keybinds (session serialization off, fixed two-pane layout: Neovim with the real config on the left, `cat` on the right) inside a tmux pty and the rows' bytes are written with `tmux send-keys -H`.

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

### Requirement: The app menu leaves Cmd+Q and Cmd+H to the terminal
The repo SHALL provide an idempotent macOS setup step that moves Alacritty's app-menu key equivalents for "Quit alacritty" to Cmd+Option+Control+Q and "Hide alacritty" to Cmd+Option+Control+H in the `org.alacritty` defaults domain, keeping every other entry of that domain. The host applies it with a make target; the sandbox VM is provisioned with it.

#### Scenario: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H
- **WHEN** the setup step runs against an empty defaults plist
- **THEN** its `NSUserKeyEquivalents` is exactly `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`

#### Scenario: Menu key setup is idempotent and keeps other entries
- **WHEN** the setup step runs twice against a defaults plist whose `NSUserKeyEquivalents` already holds `"Hide alacritty" = "@\Uf70f"` and `"Minimize" = "@m"`
- **THEN** `NSUserKeyEquivalents` is `"Quit alacritty" = "@~^q"`, `"Hide alacritty" = "@~^h"` and `"Minimize" = "@m"`, and the second run exits 0

### Requirement: Real key presses in the sandbox VM deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance (repo config) running real zellij (user keybinds, the stack layer's layout), with key events posted to that process inside the sandbox macOS VM, never on the host. Exceptions: the app menu takes Cmd+Q and Cmd+H, Cmd+Shift+-/= arrive in Alacritty's kitty encoding, and the key helper never presses Cmd+Shift+Q (system Log Out).

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut except Cmd+Q, Cmd+Shift+Q, Cmd+H, Cmd+Shift+- and Cmd+Shift+= is pressed in the Alacritty window
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

## Shortcut table
Columns of the table the "Shortcut table" requirement refers to:
- *Source* `chars`: an Alacritty `chars` binding sends the bytes verbatim. `kitty`: no binding; Alacritty's own encoding while zellij has pushed kitty keyboard flag 1 (zellij always does at startup).
- *zellij*: `pass` (unbound, bytes written to the pane), `navigator <name> <payload>` (vim-zellij-navigator writes its own bytes to the Neovim pane), or the zellij action that consumes the key.
- *Neovim receives*: the key the Neovim pane decodes, `—` when nothing arrives.
- *Mapping*: the global normal-mode mapping of that key: `` `rhs` ``, `` fn `<lua expr>` `` (callback identity), `fn` (any Lua callback), `` desc `<desc>` ``, `none` (no mapping), or `—`.

| Shortcut | Source | Alacritty sends | zellij | Neovim receives | Mapping |
|---|---|---|---|---|---|
| Cmd+E | chars | `\ee` | pass | `<M-e>` | fn |
| Cmd+G | chars | `\eg` | pass | `<M-g>` | `:Differ<cr>` |
| Cmd+B | chars | `\eb` | pass | `<M-b>` | none |
| Cmd+Q | chars | `\eq` | pass | `<M-q>` | none |
| Cmd+Shift+Q | chars | `\eQ` | pass | `<M-Q>` | none |
| Cmd+R | chars | `\er` | pass | `<M-r>` | fn `vim.lsp.buf.rename` |
| Cmd+C | chars | `\ec` | pass | `<M-c>` | none |
| Cmd+/ | chars | `\e/` | pass | `<M-/>` | `gcc` |
| Cmd+F | chars | `\ef` | ToggleFloatingPanes | — | — |
| Cmd+Shift+F | chars | `\eF` | pass | `<M-F>` | `:Telescope live_grep<cr>` |
| Cmd+W | chars | `\ew` | pass | `<M-w>` | fn `vim.diagnostic.goto_next` |
| Cmd+Shift+W | chars | `\eW` | pass | `<M-W>` | none |
| Cmd+H | chars | `\x08` | navigator move_focus_or_tab left | `<C-H>` | fn `require("smart-splits").move_cursor_left` |
| Cmd+Shift+H | chars | `\eH` | navigator resize left | `<M-h>` | none |
| Cmd+J | chars | `\ej` | MoveFocus down | — | — |
| Cmd+Shift+J | chars | `\eJ` | navigator resize down | `<M-j>` | fn `require("smart-splits").move_cursor_down` |
| Cmd+K | chars | `\ek` | MoveFocus up | — | — |
| Cmd+Shift+K | chars | `\eK` | navigator resize up | `<M-k>` | fn `require("smart-splits").move_cursor_up` |
| Cmd+L | chars | `\x0c` | navigator move_focus_or_tab right | `<C-L>` | fn `require("smart-splits").move_cursor_right` |
| Cmd+Shift+L | chars | `\eL` | navigator resize right | `<M-l>` | none |
| Cmd+- | chars | `\e-` | pass | `<M-->` | `zc` |
| Cmd+= | chars | `\e=` | pass | `<M-=>` | `zo` |
| Cmd+Shift+- | chars | `\e_` | pass | `<M-_>` | none |
| Cmd+Shift+= | chars | `\e+` | pass | `<M-+>` | none |
| Cmd+[ | chars | `\e[` | GoToPreviousTab | — | — |
| Cmd+] | chars | `\e]` | GoToNextTab | — | — |
| Cmd+9 | chars | `\e9` | pass | `<M-9>` | desc `99: Menu` |
| Shift+Return | chars | `\e[13;2u` | pass | `<S-CR>` | desc `99: Vibe` |
| Option+Return | chars | `\e}` | pass | `<M-}>` | none |
| Option+Shift+Return | chars | `\e{` | pass | `<M-{>` | none |
| Option+Q | chars | `\eq` | pass | `<M-q>` | none |
| Option+F | chars | `\e%` | pass | `<M-%>` | none |
| Option+H | chars | `\e!` | pass | `<M-!>` | none |
| Option+J | chars | `\e#` | pass | `<M-#>` | none |
| Option+K | chars | `\e$` | pass | `<M-$>` | none |
| Option+L | chars | `\e@` | pass | `<M-@>` | none |
| Option+Shift+H | chars | `\e^` | pass | `<M-^>` | none |
| Option+Shift+J | chars | `\e*` | pass | `<M-*>` | none |
| Option+Shift+K | chars | `\e(` | pass | `<M-(>` | none |
| Option+Shift+L | chars | `\e&` | pass | `<M-&>` | none |
| Ctrl+Option+H | chars | `\eΩ` | pass | `<M-Ω>` | none |
| Ctrl+Option+J | chars | `\eç` | pass | `<M-ç>` | none |
| Ctrl+Option+K | chars | `\e∫` | pass | `<M-∫>` | none |
| Ctrl+Option+L | chars | `\e≈` | pass | `<M-≈>` | none |
| Ctrl+H | kitty | `\e[104;5u` | navigator move_focus_or_tab left | `<C-H>` | fn `require("smart-splits").move_cursor_left` |
| Ctrl+L | kitty | `\e[108;5u` | navigator move_focus_or_tab right | `<C-L>` | fn `require("smart-splits").move_cursor_right` |
| Ctrl+Q | kitty | `\e[113;5u` | Quit | — | — |
| Ctrl+Return | kitty | `\e[13;5u` | pass | `<C-CR>` | fn `vim.lsp.buf.code_action` |
| Ctrl+Up | kitty | `\e[1;5A` | pass | `<C-Up>` | `:resize +2<CR>` |
| Ctrl+Down | kitty | `\e[1;5B` | pass | `<C-Down>` | `:resize -2<CR>` |
| Ctrl+Left | kitty | `\e[1;5D` | pass | `<C-Left>` | `:vertical resize -2<CR>` |
| Ctrl+Right | kitty | `\e[1;5C` | pass | `<C-Right>` | `:vertical resize +2<CR>` |

Known gaps this table pins down: Cmd+J/Cmd+K never reach Neovim (the later `shared_except "locked" "scroll"` block rebinds `Alt j`/`Alt k` to zellij `MoveFocus`); Cmd+Shift+H/J/K/L reach Neovim as lowercase `<M-h/j/k/l>` (the navigator's resize writes `ESC <dir>`), so the `<A-H/J/K/L>` resize maps are unreachable and Cmd+Shift+J/K move the cursor between splits; Cmd+Shift+-/= send `<M-_>`/`<M-+>` while folding maps `<S-D-->`/`<S-D-=>`; Ctrl+Q quits zellij.

## Collision table
| zellij key | zellij action | Shadowed Neovim key | Neovim modes |
|---|---|---|---|
| alt j | MoveFocus down | `<M-j>` | n s x |
| alt k | MoveFocus up | `<M-k>` | n s x |
| alt shift h | navigator resize left | `<M-H>` | n |
| alt shift j | navigator resize down | `<M-J>` | n |
| alt shift k | navigator resize up | `<M-K>` | n |
| alt shift l | navigator resize right | `<M-L>` | n |
| ctrl q | Quit | `<C-Q>` | n |
| ctrl s | SwitchToMode scroll | `<C-S>` | i s |
