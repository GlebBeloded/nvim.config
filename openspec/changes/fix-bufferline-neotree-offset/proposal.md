## Why
`lua/gleb/bufferline.lua:56` sets `offsets = { { filetype = "NvimTree", text = "", padding = 1 } }`, but the file tree is neo-tree (filetype `neo-tree`, left, width 35, `lua/gleb/file_tree/init.lua:153-154`). The offset never matches, so with the tree open the buffer tabs start at column 0 above the tree instead of above the editor window.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.

## What Changes
- Point the bufferline offset at filetype `neo-tree`, so the tabline is shifted right by the tree width while the tree is open.
- No capability covers bufferline yet. queue-spec decides where the requirement lives: a new `bufferline` capability (named after `lua/gleb/bufferline.lua`) or the `file-tree` capability, specified as a reference screenshot of the tabline row with the tree open and closed.
- Open questions for the user (visible UI, needs Current and Proposed renders per `docs/workflow.md` (Design renders)): the offset label (`text = ""`, `"Files"`, or the cwd name), its alignment and highlight, and whether a separator is drawn between the offset and the tabs.

## Capabilities
### Modified Capabilities
- None yet; queue-spec adds a `bufferline` capability or extends `file-tree` (see What Changes).

## Impact
- Code: `lua/gleb/bufferline.lua`; a screen test with a reference screenshot of the tabline row.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: other bufferline options and colors, the `buferFilter` rename (`cleanup-convention-targets`), and neo-tree window size or position.
