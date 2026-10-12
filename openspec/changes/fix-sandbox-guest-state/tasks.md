## Conventions for this change

- Layer: unit (`docs/testing.md`, "Adding a test for a scenario"). Both test files run on the macOS host; they need `defaults` and bash, never a VM.
- Test file: `tests/unit/shortcuts/test_sandbox.lua`, built like `tests/unit/loop/test_cleanup.lua`: a bare child (`H.child_set(child, child.start_bare)`), with `tempdir`, `write_executable` and `system` helpers copied from there. The `stub_env` pattern is the same, with stubs first on PATH.
- Restore script: `tests/sandbox/guest_restore.sh [domain]`. It is bash with `set -euo pipefail` and a header comment like `sandbox.sh`. `domain` defaults to `org.alacritty`, and tests pass a temp plist path. The checkout is the script's own repo root (`$(dirname "$0")/../..`), so tests copy it into a temp checkout's `tests/sandbox/`. Its terminal setup scripts are every executable `terminal/macos_*.sh`, run in name order with the domain as `$1`. That is the interface `terminal/macos_menu_keys.sh` on `fix-cmd-q-shortcut` already has. `auto` has none.
- Plugins: none. Built-ins only (`defaults`, bash).

## 1. Guest restore script

Scenarios: "Guest restore drops Alacritty defaults the branch does not define", "Guest restore applies the branch's own terminal setup".

- [x] 1.1 Failing test `shortcuts: Guest restore drops Alacritty defaults the branch does not define` in `tests/unit/shortcuts/test_sandbox.lua`:
  - helper `make_checkout(setup?)`: a temp dir with `tests/sandbox/guest_restore.sh` copied from `H.root` and an empty `terminal/`. An optional `setup` script body is written as `terminal/macos_test.sh` (executable).
  - seed `<tmp>/org.alacritty.plist` with `defaults write <plist> NSUserKeyEquivalents -dict-add "Quit alacritty" "@~^q" "Hide alacritty" "@~^h"`.
  - run `<checkout>/tests/sandbox/guest_restore.sh <plist>`. Expect code 0, and expect `defaults read <plist> NSUserKeyEquivalents` to exit non-zero.
  - `make test FILE=tests/unit/shortcuts/test_sandbox.lua` fails, because the script does not exist.
- [x] 1.2 Failing test `shortcuts: Guest restore applies the branch's own terminal setup` in the same file:
  - the checkout's `terminal/macos_test.sh` runs `defaults write "$1" TestKey -string fresh`.
  - the plist domain is empty (missing file).
  - run the restore. Expect code 0. `defaults export <plist> -` parsed (`plutil -convert json -o - -`) equals exactly `{ TestKey = "fresh" }`.
- [x] 1.3 Add `tests/sandbox/guest_restore.sh` (executable). It has small named functions:
  - `reset_domains`: `defaults delete "$domain"`. A missing domain is not an error, so tolerate only that exit and stay quiet.
  - `apply_terminal_setup`: run each executable `"$root"/terminal/macos_*.sh "$domain"` with nullglob, stdout to `/dev/null`.
  - main: `reset_domains`, then `apply_terminal_setup`.
- [x] 1.4 Run `make test FILE=tests/unit/shortcuts/test_sandbox.lua`: both cases pass. Then `make quick` is green (lint, trace shows both scenarios tested).

## 2. Run the restore before every e2e run

Scenario: "sandbox.sh e2e restores guest state after syncing and before the e2e layer".

- [x] 2.1 Failing test `shortcuts: sandbox.sh e2e restores guest state after syncing and before the e2e layer` in `tests/unit/shortcuts/test_sandbox.lua`. Stubs go in a temp bin dir first on PATH, each appending its argv as one line to a shared `$GUEST_LOG`:
  - `sysctl` prints `0` (host, so not `in_vm`).
  - `lume`: `get … --format json` prints `{"name":"nvim-e2e","status":"running","ipAddress":"192.0.2.1"}`.
  - `ssh` logs its last argument (the guest command) and answers:
    - `cat ~/.nvim-e2e-provisioned…` with the `PROVISION_REV` read from `tests/sandbox/sandbox.sh` by the test.
    - `stat -f %Su /dev/console` with `lume`.
    - everything else with exit 0 and no output.
  - `rsync` logs `rsync <dest>`.
  - Env: `SANDBOX_STATE` is a temp dir holding a pre-made `id_ed25519`/`.pub` pair (empty files), and `HOME` is a temp dir. `NVIM_TEST_DATA_DIR` is a temp dir with `lazy/` and `site/`. `CASE` and `E2E_FOCUS` are unset, and `E2E` is empty.
  - Run `tests/sandbox/sandbox.sh e2e` from `H.root`. Expect code 0. In the log, the index of the first `rsync` line ending in `:/Users/lume/nvim/` is less than the index of the line containing `tests/sandbox/guest_restore.sh`. That is less than the index of the line containing `make -s e2e-local`.
  - The case fails, because there is no restore line.
- [x] 2.2 In `tests/sandbox/sandbox.sh`, add `restore_guest() { gssh "$GUEST_REPO/tests/sandbox/guest_restore.sh"; }`. Call it from `e2e()` right after `sync_repo`, before `wait_gui`/`gui "make -s e2e-local…"`. Add a one-line comment saying it runs per run, not in `provision()`, so it is independent of `PROVISION_REV`. Update the header line for `sandbox.sh e2e`: "sync the repo, restore repo-controlled guest state, run the e2e layer…". `PROVISION_REV` is unchanged, because `provision()` does not change.
- [x] 2.3 Run `make test FILE=tests/unit/shortcuts/test_sandbox.lua`: all three cases pass. `make quick` is green.
- [ ] 2.4 VM check of the original bug (needs `make sandbox-up`):
  - `tests/sandbox/sandbox.sh ssh "defaults write org.alacritty NSUserKeyEquivalents -dict-add 'Quit alacritty' '@~^q' 'Hide alacritty' '@~^h'"`
  - then `make e2e` on this branch passes "Cmd+Q quits Alacritty from a real key press" and "Cmd+H never reaches Neovim from a real key press".
  - `tests/sandbox/sandbox.sh ssh "defaults read org.alacritty NSUserKeyEquivalents"` then fails.

## 3. Docs and gate

- [ ] 3.1 Update `docs/testing.md`:
  - "Sandbox VM" table, `make e2e` row: after rsyncing the checkout, it restores the repo-controlled guest state (`tests/sandbox/guest_restore.sh`: the `org.alacritty` defaults domain, then the checkout's `terminal/macos_*.sh`) before `make e2e-local`.
  - "Layout": add `guest_restore.sh` to the `sandbox/` line.
- [ ] 3.2 Hand-off for `fix-cmd-q-shortcut` (unmerged, out of this branch): this change's proposal already records it, so no code here. When that branch rebases onto `auto`, it drops its `provision()` call and `PROVISION_REV` bump. Its `terminal/macos_menu_keys.sh` is then picked up by the restore step.
- [ ] 3.3 `make check E2E=1` green.
