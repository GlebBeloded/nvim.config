## ADDED Requirements

### Requirement: Cmd chords reach Neovim as <D-…>
Cmd+O, Cmd+I, Cmd+D and Cmd+A SHALL have no Alacritty binding and no zellij `normal`-mode binding, so Alacritty sends its kitty flag-1 encoding with the Super bit (`\e[<codepoint>;9u`), zellij passes it to the Neovim pane, and Neovim receives `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`. The shortcut table lists them as `kitty` rows.

#### Scenario: Cmd chords reach Neovim through real zellij
- **WHEN** recorders are set in Neovim normal mode for `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`, `<M-o>`, `<M-i>`, `<M-d>`, `<M-a>`, `o`, `i`, `d`, `a` and the bytes `\e[111;9u`, `\e[105;9u`, `\e[100;9u`, `\e[97;9u` are sent in that order
- **THEN** exactly `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>` are recorded, in that order

#### Scenario: Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press
- **WHEN** recorders are set in Neovim normal mode for `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`, `<M-o>`, `<M-i>`, `<M-d>`, `<M-a>`, `o`, `i`, `d`, `a` and Cmd+O, Cmd+I, Cmd+D, Cmd+A are pressed in that order in the Alacritty window
- **THEN** exactly `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>` are recorded, in that order, and the Alacritty process is still running
