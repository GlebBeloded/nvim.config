## Context

See proposal.md (Why). Facts from exploration (2026-10-14):

- **No maintained plugin binds a key at runtime and saves it to disk.**
  - legendary.nvim is the reference design (keymaps, commands, functions, frecency). It was archived in Apr 2025.
  - commander.nvim is stale (last push 2024-06) and has no persistence.
- **Which plugin-window keys a registry can own.** We list every key outside `keymaps.lua`:
  - Owned through `FileType` buffer-local maps: diffview (public `diffview.actions`), and neo-tree once its default mappings are off. neo-tree runs `set_buffer_mappings` after it sets the filetype, so with defaults on it would overwrite our maps.
  - Owned only through the plugin's config table: differ, codediff, dap-ui, neotest, mason, lazy, blink, copilot.
  - Not ownable: 99 hardcodes `q` and `<CR>` in its windows.
- **lazy.nvim `keys` placeholders.** They are removed when the plugin loads, which could also remove a binding we set on the same lhs.

## Goals / Non-Goals

**Goals:** one registry, one keymap file, and binding that is deterministic and re-entrant (re-applying after a file change leaves exactly the file's bindings).

**Non-Goals:**
- No UI.
- No `when`-clause language. `when` is a Lua predicate over the context.
- No keymap inheritance or parent keymaps.

## Decisions

1. **Actions carry no keys; `settings/keymap.json` holds them all.**
   - Alternatives:
     - Default keys inside each action plus an overrides file (the VS Code / JetBrains model).
     - Keys in Lua.
   - Rejected because:
     - The diff-from-parent model only helps when defaults ship with a product. Here one person owns every key.
     - A Lua file cannot be rewritten safely at runtime.
   - JSON with `sort_keys` and an indent gives one line per change in git.
2. **File shape.**
   ```json
   {
     "git.open_differ": ["<M-g>"],
     "diag.next": ["<M-w>", "ge"],
     "file_tree.add": ["a"]
   }
   ```
   - An lhs list uses Neovim key notation.
   - An action's modes and `ft` scope come from the action itself, so the file stays one flat map.
   - An unknown id in the file is reported once (`vim.notify` WARN) and skipped.
3. **Features own their actions.** `lua/gleb/<feature>/actions.lua` returns `gleb.Action[]`, and `lua/gleb/actions/init.lua` requires the list of feature modules.
   - Alternative: one global actions file. Rejected: it couples every feature to one file and breaks rule 1.1.
4. **The registry is pure** (rule 1.3). `registry.lua` holds no plugin requires: it validates ids (unique, `<area>.<snake_case>`), merges, looks up by id, scope or lhs, and detects conflicts. `apply.lua` does the `vim.keymap.set`/`del` work and remembers what it bound, so a re-apply removes stale maps first.
5. **Adapters for config-only plugins.** `adapters/<plugin>.lua` exposes `mappings(registry, keymap)`, which returns the table that plugin's setup expects. The plugin's `gleb` config module calls it.
   - Runtime reassignment of an adapter key takes effect the next time that window opens. The palette says so when it happens.
6. **Context** = `{ win, buf, cursor, mode, selection }`, captured when an action is invoked.
   - For a key press, this is the current state.
   - For the palette, it is the state before the palette opened.
   - `run` executes with `win` current, and visual actions restore the selection first. Toggles apply to `win`/`buf`.
7. **Capture** accepts chords and sequences.
   - Each key is passed through `keytrans`. Enter finishes, Esc cancels, Backspace drops the last key.
   - Conflicts are computed per scope: the same mode, and both global or the same `ft`.
   - A sequence that is a prefix of another binding counts as a conflict, because of `timeoutlen` ambiguity.

## Risks / Trade-offs

- [The keymap file is edited by hand into invalid JSON] → the decode error is reported and the last applied bindings stay. Nothing is unbound silently.
- [Adapter keys need a window reopen] → the palette shows "applies when <plugin> reopens". A spec scenario pins this.
- [Ex-command import is large (~600)] → it is built lazily on first "show hidden" and cached per session.
- [Plugins that set defaults after `VeryLazy`] → `keymaps-migration` turns each one's defaults off. The `actions` spec adds a check that every bound lhs is owned by an action.

## Migration Plan

This change adds the infrastructure only, with fixture actions in tests. `keymaps-migration` moves real keys. Rollback is deleting `lua/gleb/actions/` and `settings/`.
