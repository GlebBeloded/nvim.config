## Why

The user decided the action registry is the only source of shortcuts. Today keys are still set in `keymaps.lua`, in feature modules (`comments`, `folding`, `ai`, `autocommands`), in plugin `mappings` tables (neo-tree, dap-ui, diffview, blink, copilot), and by plugin defaults (differ, codediff, neotest, mason, lazy, nvim-surround, Neovim's built-in `gr*`, `[d`, …). Each of these bypasses the palette and the keymap file.

Kind: feature
Adopt: loop/keymaps-migration-20261015-001832
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
- **BREAKING (docs):** keymap rules 3.1, 3.3 and 3.8 in `docs/architecture.md` are rewritten. Keys live only in `settings/keymap.json`, and a feature exposes actions in `actions.lua`. Rule 3.8 forbids new `<leader>` mappings but exempts plugin-window mappings that preserve a spec-retained plugin default.

## Capabilities

### New Capabilities
- none.

### Modified Capabilities
- `keymaps`: requirements restated in terms of actions and `settings/keymap.json`. Mapping options and descriptions come from the registry, and the ownership check is added.
- `shortcuts`: the shortcut table's *Mapping* column names action ids.
- `file-tree`: neo-tree window keys come from the registry, with defaults off.
- `git`: differ, diffview and codediff keys come from the registry, with defaults off.
- `folding`, `ai`, `autocommands`: their keys move into actions.
- `actions`: shortcut application becomes the exclusive owner of configured mappings and audits global and plugin-window ownership.

## Impact

- Code:
  - every feature module that sets keys;
  - `init.lua` (registers every feature action list before shortcut application);
  - `lua/gleb/plugins/actions.lua`, `lua/gleb/plugins/init.lua`, and `lua/gleb/plugins/plugins.lua` (plugin wiring uses `cmd`, `event`, or action-time `require`; no `keys`; defaults off);
  - `settings/keymap.json` (every key);
  - `docs/architecture.md` rules 3.x.
- **Tests:**
  - Existing keymap scenarios keep their titles and assertions. A key-press still produces the same effect; only where the mapping comes from changes.
  - New:
    - the ownership check (integration, full config);
    - an adapter round-trip for each plugin (the key in the file appears in the plugin's buffer maps);
    - stack and e2e reruns of the whole shortcut table.
- Plugins: none added or removed. Core keymaps: **no key changes meaning**. Plugin default keys we never configured disappear, and only re-registered ones remain.
- Pinned behavior remains unchanged while ownership moves:
  - `actions: Global bindings exist after VeryLazy` still holds because the registry remains applied on `VeryLazy`.
  - `ai: Keymaps exist after VeryLazy` still holds because the same 99 actions are registered before registry application.
  - `file-tree: q closes preview and tree` still holds because the neo-tree adapter invokes the existing close action.
  - `git: q closes diffview from file panel` still holds because the diffview adapter invokes `DiffviewClose`.
  - `git: Enter confirms message` still holds because the popup-local action invokes the existing confirm callback.
  - `git: Enter on empty buffer does nothing` still holds because migration does not change popup validation.
  - `git: Enter on placeholder does nothing` still holds because migration does not change placeholder filtering.
  - `git: Enter drops comment lines` still holds because migration does not change message cleanup.
  - `git: q discards popup` still holds because the popup-local action invokes the existing discard callback.
  - `keymaps: [d jumps to previous diagnostic` still holds because `diag.previous` invokes the existing `vim.diagnostic.jump` callback.
  - `keymaps: Diagnostic jump is not deprecated` still holds because the action retains `vim.diagnostic.jump`.
  - `shortcuts: Neovim mappings match the table` still holds because each table row resolves its action id through `settings/keymap.json`.
  - `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press` still holds because terminal routing is unchanged and `<C-CR>` remains assigned to the code-action id.
- Out of scope:
  - new shortcuts;
  - the shortcuts editor screen;
  - changing 99's hardcoded window keys.

## Decision (user, 2026-10-14)

- "Only source of shortcuts. Not sure why this is a question."
- Plugin-window keys are included.

## Rejected run
Run on `loop/keymaps-migration-20261015-001832` was rejected by the judge:
- fix loop exhausted with gates still red: tests
- last failures:
  make check is red:
  full log: /Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/artifacts/runs/8ce36755-81d7-44e4-8501-3688b4a7a23b/check-5.log
  ok   lint             0.2 s
  ok   specs            0.3 s
  ok   trace            0.4 s
  ok   types            1.1 s
  ok   chain            5.5 s
  FAIL smoke-health    14.6 s
  ok   stack           20.8 s
  ok   test           124.4 s
  FAIL e2e            258.9 s
  ok   smoke-startup    1.8 s
- note: loop: vim/_core/system:324: ENOENT: no such file or directory (cmd): '/Users/hlebbeladzed/.archon/workspaces/GlebBeloded/nvim.config/worktrees/loop/keymaps-migration-20261015-001832/.tests/venv/bin/python'
- note: loop: trace: 610 scenarios, 610 tested, 0 missing, 0 orphan, 1 duplicate
- note: loop: sandbox: lume ssh did not answer (rc=1): [2026-10-14T23:14:18Z] INFO: Could not verify VNC-disabled session marker; preserving it name=nvim-e2e
- note: loop: sandbox: nvim-e2e has a lume run process while Lume reports it ; waiting for it
