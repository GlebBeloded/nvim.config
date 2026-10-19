## Why

Kind: bug

Reported by the user (2026-10-19), when toggling Cmd+G:

```
E5108: Lua: vim/_core/system:322: ENOENT: no such file or directory (cwd): '/Users/hlebbeladzed/Work/finteqhub/worktrees/ENG-873/bookkeeping/gleb-changes:/Users/hlebbeladzed/Work/finteqhub/worktrees/ENG-873'
stack traceback:
        [C]: in function 'error'
        vim/_core/system:322: in function 'spawn'
        vim/_core/system:432: in function 'system'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/git/changes/git.lua:20: in function 'resolve_root'
        .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/init.lua:32: in function 'resolve_and_open'
        .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/init.lua:49: in function 'replace_tree_and_open'
        .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/init.lua:76: in function <.../hlebbeladzed/.config/nvim/lua/gleb/git/changes/init.lua:70>
        ...ebbeladzed/.config/nvim/lua/gleb/git/changes/actions.lua:7: in function 'run'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:111: in function 'execute'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:82: in function <...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:76>
```

User's repro: press Enter on a file in the Changes panel (diff tree), then press Cmd+G. The file opened that way does
not count as an independent, normal open buffer (the user's words: "it doesn't count as independent normal open
buffer"), so the next Cmd+G resolves the root from the panel's buffer instead of the opened file.

The root resolver ran `git` with a cwd built from the Changes panel's own buffer name
(`gleb-changes:/Users/.../ENG-873`) joined onto a directory, which does not exist.

## Evidence

- `lua/gleb/git/changes/view.lua:494-500` creates the panel as a non-file buffer named
  `gleb-changes://<root>#<tab>`.
- `lua/gleb/git/changes/init.lua:17-23` rejects only names matching `^%w+://`; the hyphen in
  `gleb-changes://` prevents that match, so the panel name is normalized as though it were a file path.
- `lua/gleb/git/changes/git.lua:18-20` passes that normalized value directly to `vim.system` as `cwd`, which
  produces the reported `ENOENT` before Git can run.
- `lua/gleb/git/changes/view.lua:474-486` owns the Enter path and currently edits the selected path in the
  chosen editor window, but the existing regression test does not assert that the resulting buffer is a listed,
  normal file buffer independent of the panel.

## What Changes

- A file opened with Enter from the Changes panel is a normal, independent buffer (Cmd+G and other git actions resolve
  from it like from any opened file).
- Cmd+G resolves the repository from a real path in every case, including when the current buffer is the Changes panel
  (or another non-file buffer); it never errors.

## Impact

- Behaviour: Changes-panel file opening and repository resolution for file and non-file buffers.
- Code: `lua/gleb/git/changes/{git,init,view}.lua` (`resolve_root`, `resolve_and_open`, `open_file`).
- Plugin dependencies: none added, removed, or upgraded.
- Core keymaps: unchanged.
- Out of scope: panel rendering, diff contents, navigation, and changes to the Cmd+G mapping.
- `diff: Diff view opens on the current file` still holds because this fix changes root selection for Changes-panel buffers, not how a diff opens for the current file.
- `diff: Diff view of an unchanged file opens nothing` still holds because unchanged-file detection is unaffected.
- `diff: Diff view outside a repository opens nothing` still holds because the fix preserves the no-repository outcome while preventing invalid panel-buffer paths from reaching Git.
- `diff: Diff view of a file absent from HEAD` still holds because comparison fallback behavior is unaffected.
- `diff: Diff view focuses an open view of the same file` still holds because existing diff-view reuse and focus behavior are unaffected.
- `diff: Diff view matches the approved render` still holds because this change does not alter rendering.
- `diff: Diff view marks an approximate comparison` still holds because approximate-comparison state and presentation are unaffected.
- `diff: Requirement: Diff view closing` still holds because diff-view lifecycle and closing behavior are unaffected.
- `diff: Diff view ]f without a list keeps the view` still holds because diff navigation is unaffected.
- `diff: Diff view mappings come from diff actions` still holds because mappings and action ownership are unchanged.
- `diff: Diff view checkboxes follow the index` still holds because index state and checkbox rendering are unaffected.
- `diff: Diff view marks both ends of a moved block` still holds because moved-block detection and marks are unaffected.
- `diff: Diff view moved block matches the approved render` still holds because this change does not alter moved-block rendering.
