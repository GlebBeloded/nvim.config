## Why

The user decided the action registry is the only source of shortcuts. Today keys are still set in `keymaps.lua`, in feature modules (`comments`, `folding`, `ai`, `autocommands`), in plugin `mappings` tables (neo-tree, dap-ui, diffview, blink, copilot), and by plugin defaults (differ, codediff, neotest, mason, lazy, nvim-surround, Neovim's built-in `gr*`, `[d`, …). Each of these bypasses the palette and the keymap file.

Kind: feature
Adopt: loop/keymaps-migration
Depends: action-registry, find-action

## What Changes

- Every existing shortcut becomes an action in its feature's `actions.lua`, and its key moves to `settings/keymap.json`. No physical key changes meaning; the behaviour is unchanged.
- **Global keys:** `lua/gleb/keymaps.lua` is reduced to actions (`window.*`, `jump.*`, `buffer.*`, `edit.*`, `tree.*`, `git.*`, `lsp.*`, `diag.*`). The same applies to the keys in `comments`, `folding`, `ai` and `autocommands` (`q` closes `qf`/`help`/`man`/`lspinfo`, as an `ft` action).
- **Plugin-window keys:**
  - neo-tree (`use_default_mappings = false`), dap-ui, diffview (`keymaps.disable_defaults = true`), differ, codediff, neotest, mason, lazy, blink and copilot get their keys from adapters or `ft` actions. Each plugin's defaults are turned off.
  - The two keys 99 hardcodes (`q`, `<CR>` in its windows) stay as the only exception, and are listed in the spec.
- **Built-in and plugin defaults:**
  - Neovim's default maps (`grn`, `gra`, `grr`, `gri`, `grt`, `gO`, `[d`/`]d`, `[q`/`]q`, …) that the config does not adopt are deleted at startup.
  - The ones it keeps become registry actions.
  - nvim-surround: `vim.g.nvim_surround_no_mappings = true`, with its `<Plug>` maps bound as actions.
- **lazy.nvim:** no plugin spec uses `keys` any more. Loading is triggered by `cmd`, `event`, or `require` inside an action's `run`.
- **Ownership check:** after `VeryLazy`, every mapping in modes `n x s o i c t` (global and plugin-window buffers) must be owned by an action through `keymap.json`, or appear on a short allowlist (Neovim's built-in grammar and the 99 exception).
- **BREAKING (docs):** keymap rules 3.1, 3.3 and 3.8 in `docs/architecture.md` are rewritten. Keys live only in `settings/keymap.json`, and a feature exposes actions in `actions.lua`.

## Capabilities

### New Capabilities
- none.

### Modified Capabilities
- `keymaps`: requirements restated in terms of actions and `settings/keymap.json`. Mapping options and descriptions come from the registry, and the ownership check is added.
- `shortcuts`: the shortcut table's *Mapping* column names action ids.
- `file-tree`: neo-tree window keys come from the registry, with defaults off.
- `git`: differ, diffview and codediff keys come from the registry, with defaults off.
- `folding`, `ai`, `autocommands`: their keys move into actions.

## Impact

- Code:
  - every feature module that sets keys;
  - `lua/gleb/plugins/plugins.lua` (no `keys`, defaults off);
  - `settings/keymap.json` (every key);
  - `docs/architecture.md` rules 3.x.
- **Tests:**
  - Existing keymap scenarios keep their titles and assertions. A key-press still produces the same effect; only where the mapping comes from changes.
  - New:
    - the ownership check (integration, full config);
    - an adapter round-trip for each plugin (the key in the file appears in the plugin's buffer maps);
    - stack and e2e reruns of the whole shortcut table.
- Plugins: none added or removed. Core keymaps: **no key changes meaning**. Plugin default keys we never configured disappear, and only re-registered ones remain. That list is in design.md and needs user review.
- Out of scope:
  - new shortcuts;
  - the shortcuts editor screen;
  - changing 99's hardcoded window keys.

## Decision (user, 2026-10-14)

- "Only source of shortcuts. Not sure why this is a question."
- Plugin-window keys are included.

## Rejected run
Run on `loop/keymaps-migration` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] Diffview file-panel `j`/`k` no longer do what they did before the migration. Before, the config mapped `j`/`k` to `actions.select_next_entry`/`select_prev_entry`, which open the next or previous file's diff. Now settings/keymap.json:51-52 assign them to `diffview.next_entry`/`prev_entry` (lua/gleb/git/actions.lua:107-108), which only move the cursor. This breaks the proposal's rule that no key changes meaning. Probe: in `:DiffviewOpen` with a.txt and b.txt changed, pressing `j` in the file panel leaves `cur_entry` on a.txt; before the migration it switched to b.txt. Fix: assign `j` to `diffview.select_next_entry` and `k` to `diffview.select_prev_entry`, and drop the cursor-only actions. Earlier passes missed this because the ownership tests only check desc/action identity, and spec "Diffview file panel mappings" says "next entry", which reads like diffview's `next_entry`.
  
  [must-fix] In the git_status tree, `o` and `l` changed meaning. Before, only `<cr>` was overridden to `git_open_file`; `o` and `l` stayed neo-tree's native `open` (spec file-tree:28: git_status overrides only "where they collide", and its override list at line 84 names only `<cr>`). Now `neo_tree.open` gets all three keys (settings/keymap.json:98), and its run sends every key in git_status to `git_open_file` (lua/gleb/file_tree/actions.lua:261-264). So `o` and `l` now close diffs and switch to the filesystem tree. Probe: in `Neotree git_status`, `<CR>`, `o` and `l` all resolve to `Tree: Open`. Fi
- note: flaky test cases (failed, then passed on rerun): e2e: sandbox: lume ssh did not answer (rc=1): [2026-10-15T01:44:19Z] INFO: Could not verify VNC-disabled session marker; preserving it name=nvim-e2e
