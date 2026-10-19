## Why

Kind: bug

Reported by the user (2026-10-19), "on open windows":

```
E5108: Lua: .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/view.lua:463: Vim:E444: Cannot close last window
stack traceback:
        [C]: in function 'nvim_win_close'
        .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/view.lua:463: in function 'close'
        .../hlebbeladzed/.config/nvim/lua/gleb/git/changes/init.lua:115: in function 'close'
        ...rs/hlebbeladzed/.config/nvim/lua/gleb/file_tree/view.lua:842: in function 'open_replacing_changes'
        ...rs/hlebbeladzed/.config/nvim/lua/gleb/file_tree/view.lua:1088: in function 'toggle'
        ...hlebbeladzed/.config/nvim/lua/gleb/file_tree/actions.lua:94: in function 'run'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:111: in function 'execute'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:82: in function <...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:76>
```

Toggling the project tree while the Changes panel is open closes the Changes panel first
(`open_replacing_changes`); when the panel's window is the last window of the tab, `nvim_win_close` raises E444 and the
toggle fails with a traceback. Probe which window layouts reach it (the panel alone in a tab, the panel plus only its
diff windows).

## What Changes

- Toggling the project tree with the Changes panel open replaces the panel in every layout, including when the panel's
  window is the last one in the tab, without an error.

## Evidence

- `lua/gleb/file_tree/view.lua:990-995` closes the Changes panel synchronously before opening the project tree.
- `lua/gleb/git/changes/view.lua:447-467` closes the owned diff first, but calls `nvim_win_close` on the panel without
  handling the panel being the tab's last window.
- A headless probe with the Changes panel as the tab's only window reports `windows_before = 1` and
  `Vim:E444: Cannot close last window` from `lua/gleb/git/changes/view.lua:463` when `file_tree.toggle` runs.
- A headless probe with only the Changes panel and its owned diff layout reports `ok = true`; diff teardown restores an
  editor window and the resulting layout contains `gleb-file-tree` and the restored text window.

## Impact

- `lua/gleb/git/changes/view.lua` (close), `lua/gleb/file_tree/view.lua` (`open_replacing_changes`).
- No plugin dependency is added, removed or upgraded.
- Core keymaps do not change.
- Out of scope: changing the Changes panel or project-tree appearance, or changing their shared-left-side policy.
