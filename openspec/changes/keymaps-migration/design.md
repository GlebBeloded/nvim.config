## Context

See proposal.md (Why). Inventory of keys outside `keymaps.lua`, taken 2026-10-14 against the installed plugins:

| Plugin | How keys are set today | How to turn its defaults off | How the registry reaches it |
|---|---|---|---|
| neo-tree | our `mappings` table, plus defaults | `use_default_mappings = false` | adapter (commands need `state`, from `manager.get_state_for_window()`) |
| differ | about 60 defaults (`keymaps.diff/panel/history/merge`) | each action set to `false` | adapter (mostly closures) |
| diffview | our `keymaps.view/file_panel` | `keymaps.disable_defaults = true` | `ft` actions calling `diffview.actions.*` |
| codediff | defaults (`keymaps.view/explorer/history/conflict`) | each key set to `false` | adapter |
| dap-ui | our `mappings`, plus `element_mappings` | override | adapter |
| neotest | summary `mappings` | override | adapter |
| mason, lazy | `ui.keymaps`, `ui.custom_keys` | override, or `false` | adapter |
| blink.cmp, copilot | our `keymap` tables | `preset = "none"` / `false` | adapter (insert-mode actions) |
| nvim-surround | global defaults | `vim.g.nvim_surround_no_mappings` | actions on `<Plug>` maps |
| Neovim built-ins | `defaults.lua` | `vim.keymap.del` at startup | adopted ones become actions |
| 99 | hardcoded `q`, `<CR>` | none | allowlisted exception |

## Goals / Non-Goals

**Goals:**
- Every key the user can press comes from `settings/keymap.json`.
- No behaviour change.

**Non-Goals:**
- New keys.
- Renaming keys.

## Decisions

1. **Migrate one feature at a time, test first.** For each feature:
   - its existing scenarios must pass unchanged;
   - its keys move into actions and `keymap.json`;
   - its plugin defaults turn off;
   - an adapter round-trip test is added.

   Order: global `keymaps.lua`, then comments/folding/ai/autocommands, then neo-tree, then git (differ, diffview, codediff), then debugging, then testing, then the completion plugins, then built-ins.
2. **Default keys that disappear** are listed for user review before built-ins are deleted: every plugin or built-in default not re-registered as an action. This list is produced in the design step as a table of key → action or `dropped`.
3. **Ownership check:** `actions.audit()` walks `nvim_get_keymap` (all modes) and the buffer maps of each open plugin-window filetype. Any mapping whose `desc` does not match a registered action, and that is not on the allowlist, is reported. An integration test asserts the report is empty.
4. **Rules 3.x rewrite** (`docs/architecture.md`):
   - 3.1: keys live only in `settings/keymap.json`, and features expose actions in `actions.lua`.
   - 3.3: the `desc` is derived from the action as `<Category>: <Title>`.
   - 3.8: "no `<leader>` maps" stays true, and now applies to the keymap file.

## Risks / Trade-offs

- [Silently losing a default key the user relies on] → decision 2's review table, plus the ownership check.
- [neo-tree or telescope-style plugins rebinding after `FileType`] → defaults are off, and the adapter is the only source. The round-trip test catches a rebind.
- [Insert-mode completion keys (blink) are time-critical] → the adapter writes blink's `keymap` table at setup, without a runtime indirection.

## Migration Plan

Each feature migrates in its own task, and `make check` must be green after each one. Rollback is per feature: restore its old key table.
