## Why
The sandbox VM is shared by every branch the loop tests, but guest state outside the rsynced repo is written only by `provision()`, which only adds. A run of `loop/fix-cmd-q-shortcut` wrote `defaults org.alacritty NSUserKeyEquivalents` (Quit/Hide moved off Cmd+Q/Cmd+H) into the guest; every later `auto`-based branch then failed "Cmd+Q quits Alacritty from a real key press" and "Cmd+H never reaches Neovim from a real key press" three times and escalated. A branch's e2e result must not depend on which branch ran before (root cause: `tests/sandbox/sandbox.sh:134,137-183,328-351`).

Kind: bug

## What Changes
- Every `sandbox.sh e2e` run, after `sync_repo` and before `make e2e-local`, restores the guest's repo-controlled state from the synced checkout: the `org.alacritty` defaults domain is deleted, then the branch's own terminal setup is applied (what `terminal/` of that branch defines; on `auto` nothing, so the domain stays absent).
- The restore is one guest-side step that owns the list of repo-controlled domains and setup scripts; it runs per run (cheap, idempotent), not only on provision, so it no longer depends on `PROVISION_REV`.
- Unit-layer tests: the restore against a temp plist domain, and the order of guest commands `sandbox.sh e2e` issues with `lume`/`ssh`/`rsync` stubbed.
- Follow-up for `fix-cmd-q-shortcut` (unmerged): its `provision()` call of `terminal/macos_menu_keys.sh` moves into this restore step when it rebases onto `auto`, so the menu keys are applied per run by the branch that defines them.

## Capabilities
### Modified Capabilities
- `shortcuts`: requirement "Real key presses in the sandbox VM deliver shortcuts" gains guest-state isolation between runs (ADDED requirement and scenarios).

## Impact
- Code: `tests/sandbox/sandbox.sh` (e2e path), a guest-side restore script under `tests/sandbox/`, new unit test `tests/unit/shortcuts/`; docs/testing.md "Sandbox VM" names the per-run restore.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: snapshot/clone-based VM reset (Lume clone per run, ~21 GB images); guest state the repo does not control (Homebrew packages, pinned tool versions, TCC, SIP, autologin, plugins under `~/.local/share/nvim`, already keyed by `lazy-lock.json`); deciding Cmd+Q/Cmd+H behaviour (owned by `fix-cmd-q-shortcut`); the host's `org.alacritty` defaults.
