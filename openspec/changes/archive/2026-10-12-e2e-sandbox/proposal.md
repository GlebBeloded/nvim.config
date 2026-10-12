# Proposal

## Why

The e2e layer posted real key events on the host. Cmd+Shift+Q from the shortcut table hit the macOS Log Out shortcut, and Cmd+Q quit the test window, so the remaining rows timed out (81 s). The spec claimed both rows reach Neovim from a real key press, which they never do.

## What Changes

- **BREAKING (tests only)**: e2e runs only inside a Lume macOS VM (`make sandbox-up`); `make e2e` on the host syncs the repo into it and runs the layer in the guest's GUI session. The key helper refuses to post outside a VM and never presses a denylist of system-wide chords.
- The requirement "Real key presses in the sandbox VM deliver shortcuts" (replacing "Real key presses in Alacritty deliver shortcuts") states current behaviour, measured in the VM: the app menu takes Cmd+Q (Alacritty quits; its own case, on a fresh stack) and Cmd+H (Hide; "Cmd+H moves to the left Neovim split from a real key press" becomes "Cmd+H never reaches Neovim from a real key press"); Cmd+Shift+-/= arrive as `<S-D-->`/`<S-D-=>` (Alacritty's `key = "Minus"`/`"Equals"` + Shift bindings never match); Cmd+Shift+Q is the system Log Out shortcut and is never pressed (the helper refuses it). "Every passed shortcut" covers the other rows.
- Harness: liveness check after every press, event-driven waits, a startup timeline plus Alacritty log and zellij stderr in failures, a probe that needs the actual probe key.

## Capabilities

### New Capabilities

### Modified Capabilities

- `shortcuts`: "Real key presses in Alacritty deliver shortcuts" is replaced by "Real key presses in the sandbox VM deliver shortcuts", which excludes Cmd+Q, Cmd+Shift+Q, Cmd+H and Cmd+Shift+-/= from "Every passed shortcut", replaces "Cmd+H moves to the left Neovim split from a real key press" with "Cmd+H never reaches Neovim from a real key press", and gains "Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press", "Cmd+Q quits Alacritty from a real key press" and "Cmd+Shift+Q is never pressed: the key helper refuses it".

## Impact

Tests, Makefile and docs only (tests/e2e/, tests/sandbox/, tests/shortcuts/stack.lua, tests/quick.sh, Makefile, docs/testing.md). No plugin dependency change. No core keymap change. Out of scope: making Cmd+Q / Cmd+H / Cmd+Shift+Q reach Neovim (queued as `fix-cmd-q-shortcut`), fixing the Cmd+Shift+-/= bindings and table rows (queued as `fix-cmd-shift-minus-equal`), Linux guests, screenshots of the window.
