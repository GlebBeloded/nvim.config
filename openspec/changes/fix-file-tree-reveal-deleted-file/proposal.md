## Why
User report (2026-10-15): opening the file tree (Toggle File Tree, `⌘E`) raised E5108 while files were being deleted and added in the background:

```
neo-tree/command/parser.lua:108: Invalid path: /Users/hlebbeladzed/Work/personal/metodichka/backend/main.rs is not a file
  gleb/file_tree/actions.lua:67: in function 'smart_toggle'
  gleb/file_tree/actions.lua:250: in function 'run'
  gleb/actions/context.lua:89: in function 'run'
```

Kind: bug

## Evidence
- `lua/gleb/file_tree/actions.lua:64-69`: for the filesystem source, `smart_toggle` runs `Neotree reveal_file=<current buffer path>` whenever the buffer has a non-URI name. It never checks that the file still exists on disk, so neo-tree's parser (`parser.lua:108`) errors when the buffer's file was deleted (or not yet written).

## What Changes
- Toggle File Tree never errors when the current buffer's file is missing on disk (deleted, renamed or never written). It opens the tree focused with no reveal, or reveals the nearest existing parent directory.
- A regression test replays the trigger: open a file, delete it on disk, then run the real Toggle File Tree mapping.

## Impact
- Code: `lua/gleb/file_tree/actions.lua`.
- Tests: file_tree integration.
