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

## What Changes

- A file opened with Enter from the Changes panel is a normal, independent buffer (Cmd+G and other git actions resolve
  from it like from any opened file).
- Cmd+G resolves the repository from a real path in every case, including when the current buffer is the Changes panel
  (or another non-file buffer); it never errors.

## Impact

- `lua/gleb/git/changes/{git,init}.lua` (`resolve_root`, `resolve_and_open`).
