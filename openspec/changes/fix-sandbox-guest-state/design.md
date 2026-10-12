## Context
Guest state outside `~/nvim` (the rsynced checkout) is written only by `provision()` in `tests/sandbox/sandbox.sh`, gated by `PROVISION_REV`. Provisioning is additive, so a branch that writes guest state (here `org.alacritty NSUserKeyEquivalents`) leaves it behind for every later branch.

## Goals / Non-Goals
Goals: each e2e run starts from the guest state its own checkout defines, for everything the repo controls; covered by unit tests that need no VM.
Non-goals: resetting what the repo does not control (tools, TCC, SIP, autologin).

## Decisions
- Proposed A (picked): a guest-side restore script in `tests/sandbox/`, synced with the repo and run by `e2e()` over `gssh` after `sync_repo`, before `gui "make -s e2e-local"`. It deletes the repo-controlled defaults domains (`org.alacritty`), then runs the setup scripts the checkout's `terminal/` defines. The domain is a parameter (default `org.alacritty`, tests pass a plist path), as `terminal/macos_menu_keys.sh` on `fix-cmd-q-shortcut` already does. Cost: a few `defaults` calls per run; idempotent.
- Proposed B: keep the step in `provision()` and bump `PROVISION_REV` on every branch that touches guest state. Rejected: switching branches only re-provisions when revs differ, and provisioning still never removes what another branch wrote.
- Proposed C: Lume clone/snapshot per run. Rejected: ~21 GB images, slow, and resets state the repo does not own (SIP, TCC, autologin) that takes minutes to rebuild.
- Testability: `sandbox.sh e2e` is tested with `lume`, `ssh`, `rsync` stubs on PATH (pattern of `tests/unit/loop/test_cleanup.lua` `stub_env`), the stub `ssh` logging each guest command; the restore script is tested directly against temp plists and a temp `terminal/` dir.

## Risks / Trade-offs
- `cfprefsd` caching: `defaults delete`/`write` go through cfprefsd, and the harness launches a fresh Alacritty per run, so the restored domain is what it reads.
- `fix-cmd-q-shortcut` currently applies menu keys in `provision()`; whichever merges second must route that call through the restore step (noted in the proposal).
