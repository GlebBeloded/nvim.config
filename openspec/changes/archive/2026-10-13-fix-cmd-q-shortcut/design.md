# Design

## Context

See proposal.md (Why, Decision: option A). No Neovim screen output changes, so this design has no renders.

Root cause: Alacritty 0.17 runs on winit, whose macOS backend (`src/platform_impl/macos/menu.rs`) builds the app
menu with `Hide <processName>` (key equivalent `h`, Command) and `Quit <processName>` (`q`, Command).
NSApplication offers a key-down to the main menu's key equivalents before the window's `keyDown:`, so the
Command+Q / Command+H `chars` bindings in `terminal/alacritty/keymaps_macos.toml` never match. `processName`
is the executable name, `alacritty` (lowercase), so the menu titles are `Quit alacritty` and `Hide alacritty`.
The host already confirms the title: `defaults read org.alacritty` holds a hand-made
`"Hide alacritty" = "@\Uf70f"` (Cmd+F12), which is why Cmd+H works on the host but not in the sandbox VM.
Cmd+Shift+Q is the system Log Out shortcut, taken before any app sees it.

Cocoa applies `NSUserKeyEquivalents` from the app's defaults domain (bundle id `org.alacritty`) to menu items
by title when the menu is set up, so a moved equivalent takes effect at the next Alacritty launch.

## Goals / Non-Goals

**Goals:**
- A versioned, idempotent setup step in `terminal/` that moves Quit and Hide off Cmd+Q / Cmd+H; a make target
  for the host; the sandbox VM restored from the checked-out branch before every e2e run.
- e2e proves Cmd+Q arrives as `<M-q>` and Cmd+H navigates, and the moved Quit chord still quits.

**Non-Goals:**
- Taking Cmd+Shift+Q back from the system (System Settings > Keyboard > Shortcuts stays manual).
- Giving `<M-q>` a Neovim mapping (the table keeps `none`).
- Other app-menu items (Hide Others is Cmd+Option+H, Minimize, Close) and the other byte-less Cmd shortcuts.

## Decisions

1. **`NSUserKeyEquivalents` in the `org.alacritty` domain.** One `defaults write org.alacritty
   NSUserKeyEquivalents -dict-add` call: per app, built into macOS, scriptable, survives Alacritty upgrades.
   Alternatives: Karabiner-Elements (new global dependency, rewrites keys for every app), patching or
   forking Alacritty/winit (maintenance), `NSGlobalDomain` (moves Quit/Hide in every app), System Settings
   App Shortcuts by hand (unversioned, not provisionable in the VM).
2. **New chords Cmd+Option+Control+Q (`@~^q`) and Cmd+Option+Control+H (`@~^h`).** Quit and Hide stay on
   the keyboard, deliberately hard to hit. No Alacritty binding uses Command with Option+Control (the
   Option|Control bindings match exact modifiers), zellij never sees them, and the key helper's denylist
   does not hold them. The host's hand-made F12 Hide is overwritten by the same value as in the VM.
3. **Script `terminal/macos_menu_keys.sh [domain]`**, default `org.alacritty`; a plist path as argument
   (what `defaults` accepts as a domain) lets tests run it without touching the user's defaults.
   `-dict-add` merges, so re-runs are no-ops and other entries survive. It prints that Alacritty must be
   quit and relaunched. Make target `make menu-keys` runs it on the host.
4. **Tests.** The two setup scenarios run in the chain layer (`tests/chain/shortcuts/`, macOS only like
   the rest of the chain): run the script on a temp plist, read it back with `plutil -convert json`.
   e2e: Cmd+Q and Cmd+H join the bulk case; dedicated provisioned cases prove split/pane movement, `<M-q>`
   delivery, process liveness and window visibility, while controlled no-setup cases preserve the original
   Hide/Quit regressions. The quitting case presses `cmd+ctrl+opt+q`. Window visibility is read from the key
   helper (`keys hidden <pid>`, `NSRunningApplication.isHidden`). The e2e preflight fails when the guest's
   `org.alacritty` lacks either exact entry, so a broken restore cannot pass silently.
5. **Per-run guest restore** deletes the `org.alacritty` domain after syncing the checkout, then runs every
   executable `terminal/macos_*.sh` from that branch. Checkout-specific menu state therefore never depends
   on the one-time `PROVISION_REV`.
6. **Cmd+Shift+Q keeps its binding and table row** (chain and stack still verify the byte path, and it works
   once Log Out is remapped); the main spec's table notes mark it unreachable by default. Dropping the row
   was rejected: the binding is harmless and becomes useful after a System Settings remap.

## Risks / Trade-offs

- [winit renames the menu or the process name changes] → the chain test pins the titles; the e2e Cmd+Q and
  Cmd+H cases fail on the next Alacritty update in the VM.
- [macOS ignores per-app `NSUserKeyEquivalents` unless the app is listed in `com.apple.universalaccess`
  `com.apple.custommenu.apps`] → e2e in the VM proves it; if it fails there, the script also adds
  `org.alacritty` to that list (a design-level fallback, no spec change).
- [Setup applied but Alacritty still running] → the script says to relaunch; e2e always starts a fresh
  Alacritty.
- [A stray Cmd+Option+Control+Q still quits everything] → accepted; it is a three-modifier chord.

## Migration Plan

Host: `make menu-keys`, then quit Alacritty from the menu and relaunch. Rollback:
`defaults delete org.alacritty NSUserKeyEquivalents` (also drops the old F12 Hide).
