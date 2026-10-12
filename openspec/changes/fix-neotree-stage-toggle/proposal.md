## Why
`<space>` in the neo-tree `git_status` tree decides staged vs unstaged with a substring search of `git diff --cached --name-only` (`file_tree/init.lua:60-68`), so a staged `aa.lua` makes `a.lua` look staged, and it searches for a cwd-relative path (`fnamemodify(":.")`) in a list of git-root-relative paths, so it is wrong whenever cwd is not the repo root. `git add` / `git reset` run via `vim.fn.system` shell strings and their result is ignored (`:71-73`, conventions.md 6.4).

Kind: bug

## What Changes
- Compare the node path, made relative to the git root, against whole lines of `git diff --cached --name-only` (or ask git with a pathspec for that path).
- Run `git add` / `git reset` via `vim.system` with an argument list; on non-zero exit notify `Stage failed: <stderr>` / `Unstage failed: <stderr>` at ERROR. Refresh `git_status` either way.

## Capabilities
### Modified Capabilities
- `file-tree`: adds a requirement that `<space>` staging matches exact repository paths and reports failures. The existing "Git status open, close and staging actions" block stays as is (it holds when cwd is the repo root).

## Impact
- Code: `lua/gleb/file_tree/init.lua` (`git_toggle_stage`)
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: directory nodes (keep current behaviour: staged if any file under them is staged), `c` commit (fix-neotree-commit-check), `A`/`gr` neo-tree built-ins.
