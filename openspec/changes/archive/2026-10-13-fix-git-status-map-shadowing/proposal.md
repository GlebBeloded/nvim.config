## Why
The neo-tree `git_status` window maps `gr` to `git_revert_file` and `c` to the AI commit (`file_tree/init.lua:217,220`). `gr` shadows the global LSP references map (`keymaps.lua:105`, telescope `lsp_references`) and `c` shadows the common neo-tree `copy` map (`file_tree/init.lua:167`), so the same key does something different, and `gr` is destructive (discards working-tree changes), in this one tree.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.

Open question (needs the user): which keys replace `gr` (revert) and `c` (commit) in `git_status`? Candidates: `X` or `gR` for revert (neo-tree has no default `X`), `C` or `cc` for commit (fugitive/diffview use `cc`). Should revert ask for confirmation?

## What Changes
- Move `git_revert_file` and the AI commit off `gr` and `c` to the keys the user picks; leave `gr` and `c` to their global / common meaning in the `git_status` tree.
- Update the file-tree spec mapping lists and scenarios, the shortcuts spec if affected, and the help (`?`) labels.

## Capabilities
### Modified Capabilities
- `file-tree`: Git status open, close and staging actions; Git status commit and push (new keys).

## Impact
- Code: `lua/gleb/file_tree/init.lua`
- Port: first implemented on `loop/fix-git-status-map-shadowing`, which conflicts with `auto` after fix-neotree-commit-check landed; this change merges it and moves commit-check's async commit and `Commit failed:` reporting from `c` to `gc` (design.md, Port onto `auto`).
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged globally; buffer-local `git_status` keys change (user decision)
- Out of scope: commit/stage correctness (fix-neotree-commit-check, fix-neotree-stage-toggle), other neo-tree default maps.

## Decision (user, 2026-10-12)
Agent decides the new keys (avoid shadowing global and common neo-tree maps; revert must ask for confirmation). Record the choice and the reason in design.md.
