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

The root resolver ran `git` with a cwd built from the Changes panel's own buffer name
(`gleb-changes:/Users/.../ENG-873`) joined onto a directory, which does not exist.

## What Changes

- Cmd+G resolves the repository from a real path in every case, including when the current buffer is the Changes panel
  (or another non-file buffer); it never errors.

## Impact

- `lua/gleb/git/changes/{git,init}.lua` (`resolve_root`, `resolve_and_open`).
