## Why

Shortcuts are spread over `keymaps.lua`, feature modules, plugin `mappings` tables, lazy.nvim `keys` specs and plugin defaults, so nothing can list every action, show its shortcut, or rebind it at runtime. A Find Action palette (`find-action`) needs one registry of actions and one file of shortcuts underneath it.

Kind: feature
Adopt: loop/action-registry

## What Changes

- New `lua/gleb/actions/`: a typed action registry, the keymap store, keymap application, key capture and the action context. It contains no UI.
- **Each feature exposes its own actions** in `lua/gleb/<feature>/actions.lua`, which returns `gleb.Action[]`. An action carries an id (`git.open_differ`), a short title (`Open Differ`), a category (`Git | Diff`), `run(ctx)`, optional `modes`, optional `ft` (the action exists only inside that plugin window), optional `when(ctx)` (whether it is available), optional `toggle` (get/set) and optional `aliases`. Actions carry no keys.
- **One keymap file is the only source of shortcuts**: `settings/keymap.json`, which maps each action id to its lhs list (Neovim key notation). It holds every shortcut, defaults included; there is no separate defaults/overrides layer. Runtime assignment and hand edits both write this file. It is written with `vim.json.encode(t, { indent = "  ", sort_keys = true })` so git diffs stay stable, and the user commits it manually.
- Application: every lhs in the file is bound with `vim.keymap.set`. The `desc` is `<Category>: <Title>`. Global actions are bound once; `ft` actions are bound buffer-local on `FileType`. Bindings are applied after `VeryLazy`, and an action's `run` loads its plugin through `require`/`:Cmd`, never through a lazy.nvim `keys` placeholder.
- **Plugin adapters** (`lua/gleb/actions/adapters/<plugin>.lua`) build a plugin's `mappings`/`keymaps` config table from the registry, for plugins whose window keys can only be set through config. This covers differ, codediff, dap-ui, neotest, mason, lazy, blink and neo-tree with `use_default_mappings = false`. diffview binds through `ft` actions using `diffview.actions`.
- Action context: invoking an action records where it was invoked: window, buffer, cursor, mode and visual selection. `when`, `toggle` and `run` receive that context, so running an action from the palette behaves exactly as pressing its shortcut there would.
- Capture: reads a chord or a key sequence (`getcharstr` + `keytrans`). Enter ends the capture, Esc cancels and Backspace drops the last key. It reports conflicts with other actions in the same scope (mode + global/ft).
- Hidden actions: every Ex command (`getcompletion("", "command")`) not already registered becomes a hidden action with a humanized title (`DiffviewOpen` → `Diffview Open`), category `Command`/`Ex`. Hidden actions cannot hold shortcuts.

## Capabilities

### New Capabilities
- `actions`: the action registry, the keymap file, how bindings are applied (global, `ft`, plugin adapters), the action context, key capture and conflict detection, and hidden Ex-command actions.

### Modified Capabilities
- none; existing keymaps move onto the registry in `keymaps-migration`.

## Impact

- Code: new `lua/gleb/actions/` (registry is pure logic per rule 1.3), `settings/keymap.json`, `init.lua` (apply after VeryLazy).
- Tests: unit (registry, store round-trip and formatting, conflicts, capture parsing, humanized Ex titles), integration (apply/re-apply, `ft` binding, adapter output, context restore). Every scenario is verified by an automated layer.
- Docs: `docs/architecture.md` module map, plus a new convention: a feature's actions live in `actions.lua` and keys only in `settings/keymap.json`.
- Plugins: none added or removed. Core keymaps: unchanged in this change.
- Out of scope: the palette UI (`find-action`), the shared picker (`picker-ui`), moving existing keymaps (`keymaps-migration`), and a shortcuts editor screen (later).

## Decision (user, 2026-10-14)

- Commands **and** plugin-window keys go into the registry ("those are lua functions in good plugins anyways").
- The registry is the **only source of shortcuts**.
- Shortcuts are saved in the repo, in a directory rather than the repo root ("I like repo root to be clean"), and the user syncs them to git manually.
- Both chords and key sequences can be assigned.
- Each package exposes its actions in a clean, idiomatic way.

## Rejected run
Run on `loop/action-registry` was rejected by the judge:
- blocked: tasks.md: ## Blocked

- Probe: not needed because the deterministic test exposed the value directly: `Left: "[]"`, `Right: "{}"`.
- Attempt 1: the shortcut store passed the four listed scenarios, but review of the repository's initial `{}` file exposed that empty Lua tables were rejected as lists.
- Attempt 2: empty tables were accepted, but `vim.json.encode` serialized the empty shortcut map as `[]`; `actions: Shortcut file round-trips deterministically` remained red.

## Unblocked
Technical, not a user decision: encode an empty shortcut map with `vim.empty_dict()` (or a JSON object
writer) so `{}` round-trips; empty Lua tables stay valid maps. Continue the adopted branch.
