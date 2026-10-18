## Why

Kind: bug

The user hit these errors in a normal session (2026-10-18, a Rust file in `~/Work/personal/metodichka/backend`):

```
vim.lsp.get_buffers_by_client_id() is deprecated. Run ":checkhealth vim.deprecated" for more information
E5108: Lua: ...s/hlebbeladzed/.config/nvim/lua/gleb/folding/actions.lua:7: Vim:E490: No fold found
stack traceback:
        [C]: in function 'normal'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/folding/actions.lua:7: in function 'run'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:111: in function 'execute'
        ...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:82: in function <...s/hlebbeladzed/.config/nvim/lua/gleb/actions/context.lua:76>
E211: File "~/Work/personal/metodichka/backend/src/domain/workflows/mod.rs" no longer available
paste: Lua: [string "vim/_core/editor"]:207: Vim:E21: Cannot make changes, 'modifiable' is off
stack traceback:
        [C]: in function 'nvim_put'
        [string "vim/_core/editor"]:207: in function <[string "vim/_core/editor"]:153>
```

1. **Fold actions throw.** `fold.open_one` (`<M-=>`, Expand Fold) runs `normal! zo` in `lua/gleb/folding/actions.lua:7`; with no
   fold under the cursor Vim raises E490 and the mapping prints an E5108 Lua traceback. `fold.close_one`
   (`<M-->`, line 12, `zc`) has the same path. Expanding or collapsing where there is no fold should do nothing
   (IntelliJ does nothing), with no error and no traceback.
2. **Paste into a read-only buffer prints a Lua traceback.** A paste (`vim.paste`, e.g. Cmd+V from the terminal)
   into a buffer with `'modifiable'` off raises E21 from `nvim_put` with a traceback. Probe which of this config's
   buffers it was (the project tree, the Changes panel, a diff view side, a help or picker window) and whether
   pasting there is reachable by normal use; the expected result is a short "read-only" message or nothing, never
   a traceback.
3. **Deprecation warning** comes from `rustaceanvim` (`lua/rustaceanvim/server_status.lua:52`, pinned
   `88575b98` in lazy-lock.json), not from this config. Check whether a newer rustaceanvim commit removes the call;
   if so, record it for the plugin update flow; do not patch the plugin.

`E211` is Vim's normal notice for a file deleted outside Neovim and is not part of this change.

## What Changes

- Fold actions: skip `zo`/`zc` when no fold is under the cursor (`foldlevel(".") == 0`), or run them so E490 is
  swallowed, keeping the count behaviour of `Context.counted`.
- Paste: for the buffer the probe finds, stop the traceback (a message saying the buffer is read-only, or the
  paste ignored), without changing paste in normal buffers.

## Impact

- lua/gleb/folding/actions.lua; the read-only buffer's module (whichever the probe shows).
- Tests: `tests/integration/folding/test_shortcuts.lua` gains the no-fold cases through the real `<M-=>` and
  `<M-->` mappings, asserting no error message.
