## 1. Move core and feature mappings into action lists
Scenarios: `actions: Feature actions contain no shortcut keys`, `actions: Every configured action is registered`, `keymaps: Core mappings resolve through actions`
- [x] 1.1 Write the scenarios in `tests/integration/actions/test_ownership.lua` and `tests/integration/keymaps/test_keymaps.lua`; drive the full startup catalog and the real configured lhs values after `VeryLazy`, run `make test FILE=tests/integration/actions/test_ownership.lua CASE="actions: Feature actions contain no shortcut keys"` and see it fail
- [x] 1.2 Add small feature-owned `actions.lua` lists for the existing core, comments, folding, AI, git, file-tree, and special-buffer behaviors; assemble them in `init.lua`; move every lhs to `settings/keymap.json`; remove direct mapping setup; update keymap rules 3.1, 3.3, and 3.8 in `docs/architecture.md`
- [x] 1.3 Run `make test FILE=tests/integration/actions/test_ownership.lua` and `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Core mappings resolve through actions"` and see them pass

## Agent decisions

- A filetype action accepts a filetype list so the one special-buffer close behavior remains one action across all four filetypes.
- Direct function mappings use the action `mapping` field to preserve callback identity for LSP, picker, and smart-splits behavior.

## 2. Remove unowned built-in and surround defaults
Scenarios: `actions: Every configured mapping is action-owned`, `keymaps: Unadopted built-in mappings are removed`, `keymaps: Adopted built-in mappings are registry actions`, `keymaps: Surround mappings use registered actions`, `keymaps: [d jumps to previous diagnostic`
- [ ] 2.1 Write the scenarios in `tests/integration/actions/test_ownership.lua` and `tests/integration/keymaps/test_keymaps.lua`; load the full config, fire `VeryLazy`, query the real default and surround lhs values, and press `[d`; run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Unadopted built-in mappings are removed"` and see it fail
- [ ] 2.2 Delete unadopted Neovim defaults during startup, register retained defaults as actions, disable nvim-surround defaults with `vim.g.nvim_surround_no_mappings = true`, and bind its `<Plug>` targets through actions
- [ ] 2.3 Run `make test FILE=tests/integration/actions/test_ownership.lua CASE="actions: Every configured mapping is action-owned"` and `make test FILE=tests/integration/keymaps/test_keymaps.lua` and see them pass

## Stuck

- Probe: with `Vj` active, mode was `V`, visual anchor was `{ 0, 1, 1, 0 }`, both `'<` and `'>` were `{ 0, 0, 0, 0 }`, and `J` resolved to `Edit: Move selection down`.
- Attempt 1 removed all unadopted Lua defaults and registered surround `<Plug>` mappings; the new built-in and surround scenarios passed, but the existing real `VjJ`/`VjK` paths failed with `E20: Mark not set`.
- Attempt 2 retained Neovim grammar defaults while removing only LSP, diagnostic, unimpaired, and selection defaults; `keymaps: Move selected lines down` still failed with `E20: Mark not set`.

## 3. Make plugin adapters the sole owner of plugin-window keys
Scenarios: `actions: Plugin-window mappings are action-owned`, `actions: Unconfigured defaults are absent`, `actions: Lazy specs define no shortcut keys`
- [ ] 3.1 Write the scenarios in `tests/integration/actions/test_plugin_ownership.lua`; open the real neo-tree, dap-ui, diffview, differ, codediff, neotest, mason, lazy, blink, and copilot surfaces with populated data, run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="actions: Plugin-window mappings are action-owned"`, and see it fail
- [ ] 3.2 Feed current shortcuts through each existing adapter, disable each plugin's defaults, remove every lazy.nvim `keys` field, and use `cmd`, `event`, or action-time `require` for loading
- [ ] 3.3 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua` and see it pass

## 4. Migrate neo-tree mappings without changing behavior
Scenarios: `file-tree: Tree mappings come from the shortcut file`, `file-tree: Neo-tree defaults stay disabled`, `file-tree: q closes preview and tree`
- [ ] 4.1 Write the ownership scenarios in `tests/integration/file-tree/test_tree.lua`, retain the existing real populated-tree `q` case in `tests/integration/file-tree/test_diff_preview.lua`, run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="file-tree: Tree mappings come from the shortcut file"`, and see it fail
- [ ] 4.2 Set `use_default_mappings = false` and build common, filesystem, and git-status neo-tree tables from file-tree actions and `settings/keymap.json`
- [ ] 4.3 Run `make test FILE=tests/integration/file-tree/test_tree.lua` and `make test FILE=tests/integration/file-tree/test_diff_preview.lua CASE="file-tree: q closes preview and tree"` and see them pass

## 5. Migrate diff viewer mappings without changing behavior
Scenarios: `git: Diffview mappings come from git actions`, `git: Differ mappings come from git actions`, `git: Codediff mappings come from git actions`, `git: q closes diffview from file panel`
- [ ] 5.1 Write the adapter scenarios in `tests/integration/git/test_git.lua`, drive real populated diffview, differ, and codediff views, retain the existing real file-panel `q` press, run `make test FILE=tests/integration/git/test_git.lua CASE="git: Diffview mappings come from git actions"`, and see it fail
- [ ] 5.2 Disable viewer defaults and derive each viewer's mapping table from git actions and current shortcuts
- [ ] 5.3 Run `make test FILE=tests/integration/git/test_git.lua` and see it pass

## 6. Preserve commit-popup confirmation guards through actions
Scenarios: `git: Commit popup mappings come from git actions`, `git: Enter confirms message`, `git: Enter on empty buffer does nothing`, `git: Enter on placeholder does nothing`
- [ ] 6.1 Add the ownership assertion to `tests/unit/git/test_ai_commit.lua`; use the real popup and `<CR>` presses in all listed cases, run `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: Commit popup mappings come from git actions"`, and see it fail
- [ ] 6.2 Install popup-local confirm and discard mappings from registered git actions while retaining the existing validation callbacks
- [ ] 6.3 Run `make test FILE=tests/unit/git/test_ai_commit.lua` and see it pass

## 7. Preserve commit-popup cleanup and discard behavior
Scenarios: `git: Enter drops comment lines`, `git: q discards popup`
- [ ] 7.1 Tighten the existing cases in `tests/integration/git/test_ai_commit.lua` and `tests/unit/git/test_ai_commit.lua` to invoke the active popup mappings; temporarily replace the registered `<CR>` and `q` callbacks with no-ops, run `make test FILE=tests/integration/git/test_ai_commit.lua CASE="git: Enter drops comment lines"` and `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: q discards popup"`, see them fail and record the failures, then remove the fault
- [ ] 7.2 Keep comment-line cleanup and running-job cancellation in the action callbacks
- [ ] 7.3 Run `make test FILE=tests/integration/git/test_ai_commit.lua CASE="git: Enter drops comment lines"` and `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: q discards popup"` and see them pass

## 8. Migrate 99 entry and prompt mappings
Scenarios: `ai: 99 entry mappings come from AI actions`, `ai: Prompt submit comes from a filetype action`, `ai: 99 hardcoded mappings are the only exceptions`, `ai: Keymaps exist after VeryLazy`
- [ ] 8.1 Write the ownership scenarios in `tests/integration/ai/test_prompt_keys.lua`; fire `VeryLazy`, open the real 99 prompt/window, and query its buffer mappings, run `make test FILE=tests/integration/ai/test_prompt_keys.lua CASE="ai: 99 entry mappings come from AI actions"`, and see it fail
- [ ] 8.2 Register entry and filetype-scoped submit actions, remove direct AI mapping setup, and keep only 99's hardcoded `q` and `<CR>` mappings on the allowlist
- [ ] 8.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and `make test FILE=tests/unit/ai/test_prompt_keymaps.lua` and see them pass

## 9. Preserve fold and special-buffer shortcuts through actions
Scenarios: `folding: Fold keys invoke registered actions`, `autocommands: q closes special buffers through an action`
- [ ] 9.1 Write the scenarios in `tests/integration/folding/test_shortcuts.lua` and `tests/integration/autocommands/test_keymaps.lua`; press the real fold lhs values in a folded buffer and `q` in each real special filetype, run `make test FILE=tests/integration/folding/test_shortcuts.lua CASE="folding: Fold keys invoke registered actions"`, and see it fail
- [ ] 9.2 Move fold behavior to folding actions and replace the autocmd-created `q` map with one filetype-scoped close action covering `qf`, `help`, `man`, and `lspinfo`
- [ ] 9.3 Run `make test FILE=tests/integration/folding/test_shortcuts.lua` and `make test FILE=tests/integration/autocommands/test_keymaps.lua` and see them pass

## 10. Make the shortcut table identify actions
Scenarios: `shortcuts: Shortcut table names action ids`, `shortcuts: Shortcut meanings survive registry migration`, `shortcuts: Neovim mappings match the table`, `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press`
- [ ] 10.1 Add the action-id table assertion and full-config keypress coverage to `tests/chain/shortcuts/test_chain.lua`, update the existing e2e case only to resolve the action-backed mapping, run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="shortcuts: Shortcut table names action ids"`, and see it fail
- [ ] 10.2 Replace each mapped row's implementation label with its action id while preserving every physical shortcut, byte sequence, zellij route, received key, and behavior
- [ ] 10.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua`, then run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press"` in the sandbox VM and see them pass
