## 1. Move core and feature mappings into action lists
Scenarios: `actions: Feature actions contain no shortcut keys`, `actions: Every configured action is registered`, `keymaps: Core mappings resolve through actions`
- [x] 1.1 Write the scenarios in `tests/integration/actions/test_ownership.lua` and `tests/integration/keymaps/test_keymaps.lua`; drive the full startup catalog and the real configured lhs values after `VeryLazy`, run `make test FILE=tests/integration/actions/test_ownership.lua CASE="actions: Feature actions contain no shortcut keys"` and see it fail
- [x] 1.2 Add small feature-owned `actions.lua` lists for the existing core, comments, folding, AI, git, file-tree, and special-buffer behaviors; assemble them in `init.lua`; move every lhs to `settings/keymap.json`; remove direct mapping setup; update keymap rules 3.1, 3.3, and 3.8 in `docs/architecture.md`
- [x] 1.3 Run `make test FILE=tests/integration/actions/test_ownership.lua` and `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Core mappings resolve through actions"` and see them pass

## Agent decisions

- A filetype action accepts a filetype list so the one special-buffer close behavior remains one action across all four filetypes.
- Direct function mappings use the action `mapping` field to preserve callback identity for LSP, picker, and smart-splits behavior.
- Neo-tree actions carry plugin and source-scope metadata so the global applicator skips them and the adapter composes only the relevant source table.
- Differ and Codediff retain the explicitly specified next-hunk action while their other plugin defaults are disabled, matching the ownership scenarios without inventing shortcuts.
- Commit-popup actions resolve a buffer-keyed session so registry callbacks retain each popup's validation, close, and commit context.
- The prompt-submit action covers both `99` and native completion's final `99prompt` filetype so the second FileType event retains the buffer mapping.
- Task 9 adds regression coverage only because task 1 already moved fold and special-buffer behavior into actions.
- Cmd+9 remains `none` in the normal-mode shortcut table because its configured `ai.visual` action is visual-only.
- `actions.audit()` walks global mappings in all seven modes and owns a key when `settings/keymap.json` assigns it to a registered action in that mode, so plugin-native maps on assigned keys (blink's command-line keys, autopairs' `<CR>` behind `blink.accept`) count; `<Plug>`/`<SNR>` lhs are skipped as unpressable.
- The grammar allowlist is the Neovim defaults that refine built-in keys, operators, motions and text objects: `Y`, `&`, `gc`/`gcc`, visual `*` `#` `@` `Q`, `an`/`in`, visual `[n` `]n` `[N` `]N`, matchit's `%` family, insert `<C-U>`/`<C-W>`, and snippet `<Tab>`/`<S-Tab>`.
- Startup deletes the `gr` family, `gO`, `gx`, `<C-W>d`/`<C-W><C-D>`, every `[x`/`]x` bracket pair, visual `gra`/`gx` and insert/select `<C-S>`; `[d` and `<C-S>` come back as `diag.previous` and `lsp.signature_help`, keeping the pinned Ctrl+S collision row.
- Surround actions carry a `plug` rhs that the registry maps with `remap = true`; a palette run feeds the same `<Plug>` target.
- Find Action excludes plugin-window actions: they run only through the mappings their adapter installs in that window.
- `ai.search` keeps its base title `99 Search` and category `AI` (it has no mapping), so Find Action's title-or-category match no longer ties it with `Search: Live grep`.
- Neo-tree uses one `desc` for the buffer mapping and its help row, so the help lists action descriptions; `neo_tree.commit` is titled `Commit (AI)` to keep the AI label.
- Blink actions carry blink's native command lists (`commands`) so blink keeps its fallback and select-mode behaviour; blink setup moved to `lua/gleb/cmp` because lazy.nvim runs spec `opts` before the registry exists.
- Mason and gitlinker have no "no key" value, so unassigned defaults get an unreachable `<Plug>` lhs.
- `lazy.close` is a filetype action (lazy.nvim is set up before the registry) and lazy.nvim's default custom keys are off; dap-ui's float close uses its own `dap_float` adapter area.
- The plugin-default case now queries each plugin's own buffer with an unconfigured default key: it read whichever window was current, and `<CR>` (neo-tree), `o` (dap-ui) and `<C-Space>` (blink) are configured keys; lazy.nvim's headless check is stubbed so its window opens.
- The unit copy of `git: Enter on placeholder does nothing` became `git: Popup confirm action ignores the placeholder` (integration keeps the original case).
- How should Diffview's retained conflict choices survive disabled defaults? Choose option 1: register `diffview.choose_ours`, `diffview.choose_theirs`, `diffview.choose_base`, and `diffview.choose_all` on their current `<leader>c*` keys and narrowly exempt spec-retained plugin-window defaults from rule 3.8, because this preserves both behavior and registry ownership without inventing shortcuts.
- The plugin-window audit checks every pressable buffer mapping and uses the spec's exact native-plugin allowlist for unavoidable exceptions.
- Neo-tree delete and cut use native command metadata so its renderer preserves visual/select mappings while the registry still owns their lhs values.
- Counted mappings: the action context captures `v:count` and the comment, selection-shift and single-fold actions prefix it to their native keys (`gcc`/`gc`, `>gv`/`<gv`, `zo`/`zc`), as the pre-migration remaps passed the typed count to their rhs.
- The count regression's `normal! \<Esc>` left Visual mode active, so it now presses `<Esc>`; its comment expectation is native `3gcc` (one block at the minimum indent, as the old `<A-/>` → `gcc` remap did) and its cursor sits inside both folds, since `2zo` only reaches folds containing the cursor line.
- `Registry.description` drops a title's leading category (`99` + `99 Vibe` → `99: Vibe`), so `ai.vibe` keeps its `99 Vibe` palette title and its pinned `99: Vibe` mapping description; adapters, the audit and the shortcut chain test share it.
- A buffer mapping without an action description is owned when a plugin action is assigned its lhs in that mode (plugins describe their own maps), when a `$VIMRUNTIME` script defined it (ftplugin grammar such as Go's section motions), or when it is on the native allowlist; lazy.nvim's view keys are read from `lazy.view.config` so lazy updates keep the allowlist exact.
- The stricter buffer audit exposed alpha's config-defined dashboard keys: they are `alpha.*` plugin actions whose keys an alpha adapter hands to the buttons and to alpha's `opts.keymap` press keys at render, so they still work before `VeryLazy`.
- The git-status-only `<CR>` action is `neo_tree.git_open_file`, distinguishing its source override from native common `neo_tree.open`.

## 2. Remove unowned built-in and surround defaults
Scenarios: `actions: Every configured mapping is action-owned`, `keymaps: Unadopted built-in mappings are removed`, `keymaps: Adopted built-in mappings are registry actions`, `keymaps: Surround mappings use registered actions`, `keymaps: [d jumps to previous diagnostic`
- [x] 2.1 Write the scenarios in `tests/integration/actions/test_ownership.lua` and `tests/integration/keymaps/test_keymaps.lua`; load the full config, fire `VeryLazy`, query the real default and surround lhs values, and press `[d`; run `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Unadopted built-in mappings are removed"` and see it fail
- [x] 2.2 Delete unadopted Neovim defaults during startup, register retained defaults as actions, disable nvim-surround defaults with `vim.g.nvim_surround_no_mappings = true`, and bind its `<Plug>` targets through actions
- [x] 2.3 Run `make test FILE=tests/integration/actions/test_ownership.lua CASE="actions: Every configured mapping is action-owned"` and `make test FILE=tests/integration/keymaps/test_keymaps.lua` and see them pass

## 3. Make plugin adapters the sole owner of plugin-window keys
Scenarios: `actions: Plugin-window mappings are action-owned`, `actions: Unconfigured defaults are absent`, `actions: Lazy specs define no shortcut keys`
- [x] 3.1 Write the scenarios in `tests/integration/actions/test_plugin_ownership.lua`; open the real neo-tree, dap-ui, diffview, differ, codediff, neotest, mason, lazy, blink, and copilot surfaces with populated data, run `make test FILE=tests/integration/actions/test_plugin_ownership.lua CASE="actions: Plugin-window mappings are action-owned"`, and see it fail
- [x] 3.2 Feed current shortcuts through each existing adapter, disable each plugin's defaults, remove every lazy.nvim `keys` field, and use `cmd`, `event`, or action-time `require` for loading
- [x] 3.3 Run `make test FILE=tests/integration/actions/test_plugin_ownership.lua` and see it pass

## 4. Migrate neo-tree mappings without changing behavior
Scenarios: `file-tree: Tree mappings come from the shortcut file`, `file-tree: Neo-tree defaults stay disabled`, `file-tree: q closes preview and tree`
- [x] 4.1 Write the ownership scenarios in `tests/integration/file-tree/test_tree.lua`, retain the existing real populated-tree `q` case in `tests/integration/file-tree/test_diff_preview.lua`, run `make test FILE=tests/integration/file-tree/test_tree.lua CASE="file-tree: Tree mappings come from the shortcut file"`, and see it fail
- [x] 4.2 Set `use_default_mappings = false` and build common, filesystem, and git-status neo-tree tables from file-tree actions and `settings/keymap.json`
- [x] 4.3 Run `make test FILE=tests/integration/file-tree/test_tree.lua` and `make test FILE=tests/integration/file-tree/test_diff_preview.lua CASE="file-tree: q closes preview and tree"` and see them pass

## 5. Migrate diff viewer mappings without changing behavior
Scenarios: `git: Diffview mappings come from git actions`, `git: Differ mappings come from git actions`, `git: Codediff mappings come from git actions`, `git: q closes diffview from file panel`
- [x] 5.1 Write the adapter scenarios in `tests/integration/git/test_git.lua`, drive real populated diffview, differ, and codediff views, retain the existing real file-panel `q` press, run `make test FILE=tests/integration/git/test_git.lua CASE="git: Diffview mappings come from git actions"`, and see it fail
- [x] 5.2 Disable viewer defaults and derive each viewer's mapping table from git actions and current shortcuts
- [x] 5.3 Run `make test FILE=tests/integration/git/test_git.lua` and see it pass

## 6. Preserve commit-popup confirmation guards through actions
Scenarios: `git: Commit popup mappings come from git actions`, `git: Enter confirms message`, `git: Enter on empty buffer does nothing`, `git: Enter on placeholder does nothing`
- [x] 6.1 Add the ownership assertion to `tests/unit/git/test_ai_commit.lua`; use the real popup and `<CR>` presses in all listed cases, run `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: Commit popup mappings come from git actions"`, and see it fail
- [x] 6.2 Install popup-local confirm and discard mappings from registered git actions while retaining the existing validation callbacks
- [x] 6.3 Run `make test FILE=tests/unit/git/test_ai_commit.lua` and see it pass

## 7. Preserve commit-popup cleanup and discard behavior
Scenarios: `git: Enter drops comment lines`, `git: q discards popup`
- [x] 7.1 Tighten the existing cases in `tests/integration/git/test_ai_commit.lua` and `tests/unit/git/test_ai_commit.lua` to invoke the active popup mappings; temporarily replace the registered `<CR>` and `q` callbacks with no-ops, run `make test FILE=tests/integration/git/test_ai_commit.lua CASE="git: Enter drops comment lines"` and `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: q discards popup"`, see them fail and record the failures, then remove the fault
- [x] 7.2 Keep comment-line cleanup and running-job cancellation in the action callbacks
- [x] 7.3 Run `make test FILE=tests/integration/git/test_ai_commit.lua CASE="git: Enter drops comment lines"` and `make test FILE=tests/unit/git/test_ai_commit.lua CASE="git: q discards popup"` and see them pass

## 8. Migrate 99 entry and prompt mappings
Scenarios: `ai: 99 entry mappings come from AI actions`, `ai: Prompt submit comes from a filetype action`, `ai: 99 hardcoded mappings are the only exceptions`, `ai: Keymaps exist after VeryLazy`
- [x] 8.1 Write the ownership scenarios in `tests/integration/ai/test_prompt_keys.lua`; fire `VeryLazy`, open the real 99 prompt/window, and query its buffer mappings, run `make test FILE=tests/integration/ai/test_prompt_keys.lua CASE="ai: 99 entry mappings come from AI actions"`, and see it fail
- [x] 8.2 Register entry and filetype-scoped submit actions, remove direct AI mapping setup, and keep only 99's hardcoded `q` and `<CR>` mappings on the allowlist
- [x] 8.3 Run `make test FILE=tests/integration/ai/test_prompt_keys.lua` and `make test FILE=tests/unit/ai/test_prompt_keymaps.lua` and see them pass

## 9. Preserve fold and special-buffer shortcuts through actions
Scenarios: `folding: Fold keys invoke registered actions`, `autocommands: q closes special buffers through an action`
- [x] 9.1 Write the scenarios in `tests/integration/folding/test_shortcuts.lua` and `tests/integration/autocommands/test_keymaps.lua`; press the real fold lhs values in a folded buffer and `q` in each real special filetype, run `make test FILE=tests/integration/folding/test_shortcuts.lua CASE="folding: Fold keys invoke registered actions"`, and see it fail
- [x] 9.2 Move fold behavior to folding actions and replace the autocmd-created `q` map with one filetype-scoped close action covering `qf`, `help`, `man`, and `lspinfo`
- [x] 9.3 Run `make test FILE=tests/integration/folding/test_shortcuts.lua` and `make test FILE=tests/integration/autocommands/test_keymaps.lua` and see them pass

## 10. Make the shortcut table identify actions
Scenarios: `shortcuts: Shortcut table names action ids`, `shortcuts: Shortcut meanings survive registry migration`, `shortcuts: Neovim mappings match the table`, `shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press`
- [x] 10.1 Add the action-id table assertion and full-config keypress coverage to `tests/chain/shortcuts/test_chain.lua`, update the existing e2e case only to resolve the action-backed mapping, run `make test FILE=tests/chain/shortcuts/test_chain.lua CASE="shortcuts: Shortcut table names action ids"`, and see it fail
- [x] 10.2 Replace each mapped row's implementation label with its action id while preserving every physical shortcut, byte sequence, zellij route, received key, and behavior
- [x] 10.3 Run `make test FILE=tests/chain/shortcuts/test_chain.lua`, then run `make e2e FILE=tests/e2e/shortcuts/test_e2e.lua CASE="shortcuts: Ctrl+Return reaches Neovim as <C-CR> from a real key press"` in the sandbox VM and see them pass

## 11. Preserve Diffview conflict choices through actions
Scenarios: `git: Diffview conflict choices come from git actions`, `git: <leader>co chooses ours`, `git: <leader>ct chooses theirs`, `git: <leader>cb chooses base`, `git: <leader>ca chooses all`
- [x] 11.1 Add the ownership scenario to `tests/integration/git/test_diffview.lua`; open a real populated conflict view, query the four configured lhs values, run `make test FILE=tests/integration/git/test_diffview.lua CASE="git: Diffview conflict choices come from git actions"`, and see it fail
- [x] 11.2 Register the four view-scoped `conflict_choose` actions, assign their current `<leader>c*` keys in `settings/keymap.json`, feed them through the Diffview adapter with defaults disabled, and narrow architecture rule 3.8 to exempt spec-retained plugin-window defaults
- [x] 11.3 Run `make test FILE=tests/integration/git/test_diffview.lua` and see all ownership and conflict-choice scenarios pass

## 12. Restore Diffview file-panel selection on j and k
Scenarios: `git: j selects next entry from file panel`, `git: k selects previous entry from file panel`
- [x] 12.1 Write both scenarios in `tests/integration/git/test_git.lua`; open the real picker with changed `a.txt` and `b.txt`, press `j` and `k` in its populated file panel, run `make test FILE=tests/integration/git/test_git.lua CASE="git: j selects next entry from file panel"` and see it fail
- [x] 12.2 Assign `j`/`k` to the existing select-next/select-previous actions in `settings/keymap.json` and remove the cursor-only file-panel actions
- [x] 12.3 Run `make test FILE=tests/integration/git/test_git.lua` and see both scenarios pass

## 13. Keep native o and l behavior in git-status trees
Scenarios: `file-tree: o and l keep native open in git status tree`
- [x] 13.1 Write the scenario in `tests/integration/file-tree/test_diff_preview.lua`; open a real populated `git_status` tree with an active preview, press `o` and `l` in fresh runs, run `make test FILE=tests/integration/file-tree/test_diff_preview.lua CASE="file-tree: o and l keep native open in git status tree"` and see it fail
- [x] 13.2 Keep `neo_tree.open` as the native common action for `<CR>`/`o`/`l`, add a `git_status`-scoped action that overrides only `<CR>` with `git_open_file`, and merge source-scoped mappings over common mappings
- [x] 13.3 Run `make test FILE=tests/integration/file-tree/test_diff_preview.lua CASE="file-tree: o and l keep native open in git status tree"` and see it pass
