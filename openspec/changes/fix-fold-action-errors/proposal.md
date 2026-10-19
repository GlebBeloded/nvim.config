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
- Paste: ignore terminal paste in the read-only project tree without a traceback, without changing paste in
  normal buffers.
- No plugin dependency is added, removed, or upgraded. Core keymap lhs values do not change.

## Capabilities

- `folding`: make one-fold actions harmless when no fold can be opened or closed.
- `keymaps`: keep terminal paste safe in read-only buffers and unchanged in normal buffers.

## Evidence

- `lua/gleb/folding/actions.lua:7` and `lua/gleb/folding/actions.lua:12` run counted `zo` and `zc` commands
  directly; either command raises E490 when no applicable fold is under the cursor.
- `/opt/homebrew/Cellar/neovim/0.12.5_1/share/nvim/runtime/lua/vim/_core/editor.lua:207` calls
  `nvim_put` from `vim.paste` in normal mode without checking `'modifiable'`.
- A headless full-config probe opened the populated `gleb-file-tree` buffer with `'modifiable'` off, called
  `vim.paste({ "probe" }, -1)`, and returned `false` with `Vim:E21: Cannot make changes, 'modifiable' is off`;
  the tree lines stayed unchanged. The same call in a normal modifiable buffer returned `true` and inserted
  `probe`.
- The installed rustaceanvim source at commit `88575b98` calls deprecated
  `vim.lsp.get_buffers_by_client_id` in `lua/rustaceanvim/server_status.lua:52`. Newer main commit
  `fe91aad29f77a73d48027c8983cdd9f274341f6b` replaces it with `client.attached_buffers`; that commit is
  recorded as the candidate for the separate plugin update flow.

## Impact

- Runtime: `lua/gleb/folding/actions.lua`, `lua/gleb/keymaps/init.lua`.
- Tests: `tests/integration/folding/test_shortcuts.lua` gains no-fold cases through the real `<M-=>` and
  `<M-->` mappings; `tests/integration/keymaps/test_paste.lua` covers the real project tree and normal buffers.
- `diff: Diff view zo opens a fold in both windows` still holds because its view-local `zo` action still runs
  on an existing fold; the no-fold guard does not alter that path.
- `diff: Diff view keys stay native outside view windows` still holds because native `zo` remains untouched,
  and the fold action continues to open an existing manual fold.
- `file-tree: Requirement: Project tree copy, cut and paste` still holds because its `p` action uses the tree
  clipboard rather than `vim.paste`.
- `file-tree: Requirement: Project tree refresh and operation keys` still holds because the paste guard does not
  change buffer-local tree mappings.

## Out of scope

- Vim's E211 notice for a file deleted outside Neovim.
- Updating rustaceanvim or patching its installed source; the separate plugin update flow owns that change.
