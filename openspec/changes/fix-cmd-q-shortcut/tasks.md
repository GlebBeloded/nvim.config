# Tasks

Layers (docs/testing.md): the setup step is checked in the chain layer (`tests/chain/shortcuts/`, a new
`test_menu_keys.lua`); real key presses in the e2e layer (`tests/e2e/shortcuts/test_e2e.lua`, sandbox VM
only, `make e2e`). `make trace` reads only `openspec/specs/`, so each failing-test step first copies its
scenarios from the delta into `openspec/specs/shortcuts/spec.md` (else the new cases are orphans). Design:
decisions 1–6 in design.md; no renders (no Neovim screen change).

## 1. Menu key setup step

Scenarios: "Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H", "Menu key setup is idempotent and keeps other entries".

- [x] 1.1 Failing test: add the requirement "The app menu leaves Cmd+Q and Cmd+H to the terminal" with both scenarios to `openspec/specs/shortcuts/spec.md`. In `tests/chain/shortcuts/test_menu_keys.lua` add the cases "shortcuts: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H" and "shortcuts: Menu key setup is idempotent and keeps other entries". Each writes a temp plist (`vim.fn.tempname() .. ".plist"`; the second seeds `NSUserKeyEquivalents` with `"Hide alacritty" = "@\Uf70f"` and `"Minimize" = "@m"` via `defaults write <plist> NSUserKeyEquivalents -dict ...`), runs `terminal/macos_menu_keys.sh <plist>` (twice in the second case, asserting exit 0 on the second run), and compares `vim.json.decode` of `plutil -convert json -o - <plist>` `.NSUserKeyEquivalents` exactly. Small typed helpers (`run_setup`, `read_equivalents`), no child Neovim needed. Run `make chain`: both fail (script missing); `make trace` lists them as tested, no orphans
- [x] 1.2 Add `terminal/macos_menu_keys.sh [domain]` (bash, `set -euo pipefail`, default `org.alacritty`): one `defaults write "$domain" NSUserKeyEquivalents -dict-add "Quit alacritty" "@~^q" "Hide alacritty" "@~^h"`, then print that Alacritty must be quit and relaunched. Add the `make menu-keys` target (host, runs the script with no argument). Run `make chain`: both cases pass
- [x] 1.3 Operating docs (rule 10 of docs/architecture.md): `make menu-keys` in `docs/workflow.md` "Debugging a shortcut" step 1 and one line in `docs/architecture.md` "Terminal stack" (why: the app menu takes Cmd+Q/Cmd+H). Run `make quick`: green

## 2. Real key presses in the provisioned sandbox VM

Scenarios: "Every passed shortcut reaches its Neovim key from a real key press", "Cmd+Q reaches Neovim as <M-q> from a real key press", "Cmd+H moves to the left Neovim split from a real key press", "Cmd+H in a non-Neovim pane moves zellij focus left from a real key press", "Cmd+Option+Control+Q quits Alacritty from a real key press".

- [x] 2.1 Failing test: in `openspec/specs/shortcuts/spec.md` replace the requirement "Real key presses in the sandbox VM deliver shortcuts" with the delta's "Real key presses in the provisioned sandbox VM deliver shortcuts" (all its scenarios; the two removed ones go). In `tests/e2e/shortcuts/test_e2e.lua`: drop Cmd+Q and Cmd+H from `OWN_CASE` (update its comment); delete the cases "Cmd+H never reaches Neovim from a real key press" and "Cmd+Q quits Alacritty from a real key press"; add "shortcuts: Cmd+Q reaches Neovim as <M-q> from a real key press" (`E.record(s, { "<M-q>" })`, press `cmd+q`, hits equal `{ "<M-q>" }`, pid alive, window not hidden), "shortcuts: Cmd+H moves to the left Neovim split from a real key press" (`vsplit | wincmd l`, press `cmd+h`, `wait_nvim` current window is the left one, `focused_pane()` is `NEOVIM_PANE`, window not hidden), "shortcuts: Cmd+H in a non-Neovim pane moves zellij focus left from a real key press" (like the Ctrl+H pane case), and "shortcuts: Cmd+Option+Control+Q quits Alacritty from a real key press" (`press_until_exit(get(), "cmd+ctrl+opt+q")`, last case, after Ctrl+Q). For "window not hidden" add `keys hidden <pid>` to `tests/e2e/keys.swift` (prints `true`/`false` from `NSRunningApplication(processIdentifier:).isHidden`, header comment updated) and an `E.hidden(s)` wrapper in `tests/e2e/alacritty.lua`. Check `keys denied cmd+ctrl+opt+q cmd+h cmd+q` exits non-zero. Run `make trace` (no orphans) and `make e2e` on the current, unprovisioned VM: the Cmd+Q, Cmd+H and bulk cases fail (menu still takes the keys)
- [x] 2.2 Provision the VM: in `provision()` of `tests/sandbox/sandbox.sh` run `terminal/macos_menu_keys.sh` in the guest after `sync_repo`; bump `PROVISION_REV` to 4. Run `make sandbox-provision`, then `make e2e`: all cases pass. If the Cmd+Q/Cmd+H cases still fail, apply design.md's fallback (the script also adds `org.alacritty` to `com.apple.universalaccess` `com.apple.custommenu.apps`), extend task 1's cases only if the spec changes (it does not), re-provision, rerun
- [ ] 2.3 Guard against an unprovisioned VM: `E.preflight()` in `tests/e2e/alacritty.lua` returns a failing reason with the fix `make sandbox-provision` when `defaults read org.alacritty NSUserKeyEquivalents` lacks either entry, and the e2e `start()` treats that reason as a failure, not a skip (so `make e2e` is red, not silently skipped). Verify in the guest: `defaults delete org.alacritty NSUserKeyEquivalents`, `make e2e` fails with that message; `make sandbox-provision`, `make e2e` green again
- [ ] 2.4 Update the prose: shortcut table notes in `openspec/specs/shortcuts/spec.md` mark Cmd+Shift+Q unreachable unless Log Out is remapped in System Settings > Keyboard > Shortcuts (row and binding stay, design decision 6); `docs/testing.md` e2e paragraph names the quitting chords Ctrl+Q and Cmd+Option+Control+Q and its "Sandbox VM" provisioning list names the menu key setup; the e2e file header comment likewise. Run `make chain` (table still parses) and `make quick`: green

## 3. Integration

Scenarios: all of the above.

- [ ] 3.1 Run `openspec validate fix-cmd-q-shortcut --strict` and `make check E2E=1`: every layer green, e2e in the provisioned VM, `make trace` with no orphans and none of this change's scenarios missing

## Workflow follow-up

- On the host, run `make menu-keys` and quit/relaunch Alacritty (outside the loop: it changes the user's defaults; it also replaces the hand-made F12 Hide).
- Archive the change after review.
