## 1. E2E layer

- [x] 1.1 tests/e2e/keys.swift + build.sh: launch without activation, AXIsProcessTrusted preflight, focus, CGEventPostToPid chords
- [x] 1.2 tests/e2e/alacritty.lua: Alacritty frontend for tests/shortcuts/stack.lua, background/focus probe, watchdog cleanup
- [x] 1.3 tests/e2e/shortcuts/test_e2e.lua: Every passed shortcut reaches its Neovim key from a real key press; Consumed shortcuts never reach Neovim from a real key press; Ctrl+Return reaches Neovim as <C-CR> from a real key press; Cmd+H moves to the left Neovim split from a real key press; Ctrl+Up grows the current Neovim split from a real key press; Cmd+L at the rightmost Neovim split moves zellij focus right from a real key press; Ctrl+H in a non-Neovim pane moves zellij focus left from a real key press; Ctrl+Q quits zellij and closes the Alacritty window
- [x] 1.4 Remove the gui layer; make e2e, make quick / check / gate wiring; docs/testing.md
