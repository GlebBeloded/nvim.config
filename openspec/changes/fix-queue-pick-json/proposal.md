## Why

`make queue` without `CHANGE` fails with `JSONDecodeError: Extra data` once any active change already has a `loop/<change>` branch. In `.archon/scripts/queue_pick.py`, `taken()` runs `git rev-parse --verify --quiet refs/heads/loop/<name>` without capturing its stdout. On success git prints the commit hash, so a hash line ends up before the JSON, and the `json.load` in `Makefile` (`queue` target) rejects it. After the first queued run, the queue cannot pick anything without `CHANGE`.

## What Changes

- `taken()` in `.archon/scripts/queue_pick.py` stops passing git's output through to stdout (capture it or send it to `DEVNULL`), so the script prints exactly one JSON document whichever branches exist.
- New `loop` scenario plus a unit test: `make queue` without `CHANGE` picks the oldest untaken change while another change's `loop/*` branch exists.

Plugin dependencies: none added, removed or upgraded. Core keymaps: unchanged.

## Capabilities

### New Capabilities

### Modified Capabilities
- `loop`: adds a requirement that the queue picker prints a single JSON document, so `make queue` without `CHANGE` works when changes are already taken.

## Impact

`.archon/scripts/queue_pick.py` (`taken()`), `tests/unit/loop/test_cleanup.lua` (new case reusing its repo/stub helpers). No Lua config changes.

## Out of scope

- Changes to the picking order, the `update-*` skip, or how a change's kind is detected.
- Changes to the `queue` target in `Makefile` beyond what this fix needs (it needs none).
- Other loop scripts under `.archon/scripts/`.
