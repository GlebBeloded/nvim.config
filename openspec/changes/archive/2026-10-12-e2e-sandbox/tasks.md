## 1. Sandbox

- [x] 1.1 tests/e2e/keys.swift: refuse press/focus outside a VM, denylist of system chords, `keys denied`: Cmd+Shift+Q is never pressed: the key helper refuses it
- [x] 1.2 tests/sandbox/sandbox.sh + make sandbox-up/down/status/provision; make e2e delegates into the VM; make check / quick / gate wiring
- [x] 1.3 tests/e2e: liveness after every press, fresh stack after a quitting case, timeline + logs in failures, event-driven waits: Every passed shortcut reaches its Neovim key from a real key press; Cmd+H never reaches Neovim from a real key press; Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press; Cmd+Q quits Alacritty from a real key press
- [x] 1.4 docs/testing.md sandbox section; queue fix-cmd-q-shortcut, fix-cmd-shift-minus-equal
