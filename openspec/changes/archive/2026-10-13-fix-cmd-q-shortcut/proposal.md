## Why

`fix-cmd-q-shortcut` was approved, completed and archived on `loop/fix-cmd-q-shortcut`, but its ship merge failed after `auto` independently changed the same shortcuts spec and e2e test. Current `auto` therefore still lets the macOS app menu consume Cmd+Q and Cmd+H, while the approved implementation remains stranded on the topic branch. Root cause: `artifacts/runs/b6533ff9-d997-4fda-9c8e-1bc905b96fa7/root-cause.md`.

Kind: bug

## What Changes

- Merge `loop/fix-cmd-q-shortcut` into the current change branch and resolve all conflicts semantically, retaining every test and scenario from both histories.
- Port the approved menu-key setup: Cmd+Q reaches Neovim as `<M-q>`, Cmd+H navigates splits and panes, and Cmd+Option+Control+Q becomes Alacritty's quit chord. Cmd+Shift+Q remains system-owned and is never pressed by tests.
- Preserve current `auto` behavior and coverage added since the topic fork, including Cmd+Shift+-/= fold shortcuts, Cmd+O/I/D/A, transient zellij retries, guest-state restore, sandbox locking and load-scaled deadlines.
- In the combined e2e suite, neither Cmd+Q/Cmd+H nor Cmd+Shift+-/= is excluded from the generic passed-shortcut case; all dedicated cases remain.
- Retain the current Cmd+Q-quit and Cmd+H-hidden scenarios as controlled regressions with the menu setup deliberately absent, proving both the original failure and the provisioned fix.
- Keep the topic's archive move and remove the stale live-change copy when the merged result is archived.

## Capabilities

### Modified Capabilities

- `shortcuts`: app-menu setup and real macOS key delivery for Cmd+Q/Cmd+H, merged with every current shortcut scenario.

## Impact

- Code and configuration: `Makefile`, `terminal/macos_menu_keys.sh`, sandbox provisioning/restoration, the e2e key helper and Alacritty harness.
- Tests and specs: `openspec/specs/shortcuts/spec.md`, chain menu-key tests, and the existing e2e shortcut suite. No unrelated test or scenario may be removed, skipped or weakened.
- Docs: terminal-stack intent and the existing shortcut/e2e operating instructions; no new documentation file.
- Plugins: none added, removed or upgraded.
- Core keymaps: Cmd+Q and Cmd+H behavior changes as already approved below; no additional core keymap change.
- Out of scope: new shortcut behavior beyond the approved topic; changing Cmd+Shift+Q's macOS Log Out ownership; changing current `auto` behavior for Cmd+Shift+-/=, Cmd+O/I/D/A, zellij retries, guest restore, sandbox locking or deadline scaling; refactoring the shortcut harness.

## Decision (user, 2026-10-12)

Option A: Cmd+Q, Cmd+H (and Cmd+Shift+Q where possible) reach Neovim. Move Alacritty's app-menu key equivalents for Quit and Hide off Cmd+Q / Cmd+H (`defaults write org.alacritty NSUserKeyEquivalents`), as a versioned, idempotent setup step in the repo (`terminal/`), applied on the host by a make target and provisioned in the sandbox VM. Prove with e2e scenarios that Cmd+Q arrives as `<M-q>` and Cmd+H navigates splits/panes. Cmd+Shift+Q (system Log Out) is never pressed by tests; mark its row unreachable unless remapped in System Settings.
