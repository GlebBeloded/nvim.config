# Design

## Context

See proposal.md - Why. The `git_status` window mappings in `lua/gleb/file_tree/init.lua` are merged by neo-tree with its own `git_status` defaults (`use_default_mappings` is on) and with the common `window.mappings`. So deleting our `gr` line is not enough: neo-tree's default `git_status` table also maps `gr` to `git_revert_file` (plus `ga gu gU gt gc gp gg`). A mapping value of `"none"` makes neo-tree skip the key, leaving the global map in effect. Our `c` overrides the common `c = "copy"`; removing it restores `copy`.

neo-tree's `git_revert_file` already asks `Are you sure you want to revert <name>?` (`inputs.confirm`) and only runs `git checkout HEAD -- <path>` on yes, so the user's "revert must confirm" decision needs no custom code.

The `?` help shows each mapping's `desc`, or `<function>` for a bare function, so `c -> <function>` today does not say what it does.

## Goals / Non-Goals

**Goals:**
- `gr` in the `git_status` tree is the global Telescope `lsp_references` map; `c` is `copy` like every other tree.
- Revert and AI commit sit on keys that shadow no global map and no other neo-tree map, and revert keeps its confirmation.

**Non-Goals:**
- Labels for the other custom function maps (`<cr>`, `<space>`, `P`, `j`, `k`, `q`) in help.
- neo-tree's own `git_*` defaults (`ga`, `gu`, `gU`, `gt`, `gp`, `gg`) stay as they are.

## Decisions

**Revert on `X`** (user decision: the agent picks, revert confirms). `X` is unmapped in all neo-tree defaults and in this config, and an uppercase key is harder to hit by accident than `gr`; in vim `X` already means "delete", which fits a destructive action. The built-in `git_revert_file` command is kept for its confirmation prompt. Alternatives: `gR` (neo-tree-like `g` prefix, but one shift away from `gr`, the slip this change is about); `D` (reads as delete-file, next to `d` delete).

**AI commit on `gc`.** neo-tree's `git_status` defaults already bind `gc` to its plain `git_commit`, so `gc` means "commit" in this tree today and no extra global key is shadowed (Neovim's `gc` comment operator does nothing in the non-modifiable tree, and neo-tree maps with `nowait`, so `gcc` does not delay it). The mapping is a table `{ git_commit, desc = "commit (AI)" }` so help shows a label. Alternatives: `C` (common neo-tree `close_node` default, so it would recreate the bug); `cc` (fugitive style, but a prefix of `c` copy, which then waits `timeoutlen`).

**`gr = "none"`** instead of only deleting our line, because the neo-tree default would otherwise still bind `gr` to revert.

**Spec: REMOVED + ADDED** for the commit requirement, because a MODIFIED block cannot rename the scenario "c commits confirmed message"; the new requirement "Git status AI commit and push" keeps the `P` scenario titles.

## Renders

Current, 100x40, Normal mode, `git_status` tree with one modified file (`lua/gleb/file_tree/init.lua`) after `?`, cursor in the help popup (measured with a temporary `make render MONO=1` case):

```text
       [No Name]
  GIT STATUS for /Users/hlebbelad╭─────────────────── Neotree Help ────────────────────╮
   ▾ ■ lua                       │█Press the corresponding key to execute the command. │
     ▾ ■ gleb                    │               Press <Esc> to cancel.                │
       ▾ ■ file_tree             │                                                     │
         M ◆ init.lua            │         KEY(S)    COMMAND                           │
                                 │              < -> prev_source                       │
                                 │  <2-LeftMouse> -> open                              │
                                 │          <C-b> -> scroll_preview                    │
                                 │          <C-f> -> scroll_preview                    │
                                 │          <C-r> -> clear_clipboard                   │
                                 │           <bs> -> close_node                        │
                                 │           <cr> -> <function>                        │
                                 │          <esc> -> cancel                            │
                                 │        <space> -> <function>                        │
                                 │              > -> next_source                       │
                                 │              ? -> show_help                         │
                                 │              A -> git_add_all                       │
                                 │              C -> close_node                        │
                                 │              P -> <function>                        │
                                 │              R -> refresh                           │
                                 │              S -> open_split                        │
                                 │              a -> add                               │
                                 │              b -> rename_basename                   │
                                 │              c -> <function>                        │
                                 │              d -> delete                            │
                                 │              e -> toggle_auto_expand_width          │
                                 │             gU -> git_undo_last_commit              │
                                 │             ga -> git_add_file                      │
                                 │             gc -> git_commit                        │
                                 │             gg -> git_commit_and_push               │
                                 │             gp -> git_push                          │
                                 │             gr -> git_revert_file                   │
                                 │             gt -> git_toggle_file_stage             │
                                 │             gu -> git_unstage_file                  │
                                 │              h -> close_node                        │
                                 │              i -> show_file_details                 │
                                 │              j -> <function>                        │
                                 ╰─────────────────────────────────────────────────────╯
```

Proposed, 100x40, same state; `X` revert added, `c` is `copy`, `gc` is the labelled AI commit, `gr` gone (measured with the proposed mappings applied temporarily):

```text
       [No Name]
  GIT STATUS for /Users/hlebbelad╭─────────────────── Neotree Help ────────────────────╮
   ▾ ■ lua                       │█Press the corresponding key to execute the command. │
     ▾ ■ gleb                    │               Press <Esc> to cancel.                │
       ▾ ■ file_tree             │                                                     │
         M ◆ init.lua            │         KEY(S)    COMMAND                           │
                                 │              < -> prev_source                       │
                                 │  <2-LeftMouse> -> open                              │
                                 │          <C-b> -> scroll_preview                    │
                                 │          <C-f> -> scroll_preview                    │
                                 │          <C-r> -> clear_clipboard                   │
                                 │           <bs> -> close_node                        │
                                 │           <cr> -> <function>                        │
                                 │          <esc> -> cancel                            │
                                 │        <space> -> <function>                        │
                                 │              > -> next_source                       │
                                 │              ? -> show_help                         │
                                 │              A -> git_add_all                       │
                                 │              C -> close_node                        │
                                 │              P -> <function>                        │
                                 │              R -> refresh                           │
                                 │              S -> open_split                        │
                                 │              X -> git_revert_file                   │
                                 │              a -> add                               │
                                 │              b -> rename_basename                   │
                                 │              c -> copy                              │
                                 │              d -> delete                            │
                                 │              e -> toggle_auto_expand_width          │
                                 │             gU -> git_undo_last_commit              │
                                 │             ga -> git_add_file                      │
                                 │             gc -> commit (AI)                       │
                                 │             gg -> git_commit_and_push               │
                                 │             gp -> git_push                          │
                                 │             gt -> git_toggle_file_stage             │
                                 │             gu -> git_unstage_file                  │
                                 │              h -> close_node                        │
                                 │              i -> show_file_details                 │
                                 │              j -> <function>                        │
                                 ╰─────────────────────────────────────────────────────╯
```

No color change: the help popup and tree keep their highlight groups.

## Risks / Trade-offs

- [Muscle memory for `c` and `gr`] → `?` help lists the new keys; `c` now prompts for a copy destination instead of committing, which is harmless when cancelled.
- [fix-neotree-commit-check also modifies "Git status commit and push"] → whichever change archives second rebases its delta onto "Git status AI commit and push" (and its scenario key `c` → `gc`).
- [The help screenshot depends on neo-tree's default map list] → a neo-tree upgrade that changes defaults updates the reference screenshot in the same change, as for any screen test.
