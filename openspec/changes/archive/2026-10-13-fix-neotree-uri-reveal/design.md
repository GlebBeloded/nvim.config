# Design

## Context

The keymap already distinguishes ordinary paths from `scheme://` buffer names. The URI branch invokes
`:Neotree focus filesystem`, but neo-tree's command layer interprets an omitted `reveal` as true whenever
`filesystem.follow_current_file.enabled` is true. It obtains the URI buffer name as the path to reveal and
opens the outside-cwd confirmation popup before focusing the tree.

## Goals / Non-Goals

**Goals:** Focus the existing filesystem tree from a URI buffer without revealing that buffer or opening a
confirmation popup; keep ordinary-file reveal behaviour.

**Non-Goals:** Change following for ordinary files, including files outside the cwd; disable
`follow_current_file` globally; change neo-tree configuration or plugin wiring.

## Decision

Use neo-tree's Lua command API for the URI branch and pass `reveal = false` explicitly. This preserves the
global follow setting while overriding its implied reveal for the one input class the keymap already rejects.
Passing a cwd as `dir` would also suppress the popup, but it relies on the reveal handler discarding the URI;
disabling `follow_current_file` would regress ordinary navigation.

## Visible behaviour

**Current**: `80x8`, Normal mode, `vscodediff://x`, after `<A-e>`; confirmation popup focused

```text
local change = {}                                                               
                                                                                
             ╭────────────────────────────────────────────────────╮             
             │ File not in cwd. Change cwd to vscodediff:? y/n   █│             
             ╰────────────────────────────────────────────────────╯             
                                                                                
                                                                                
                                                                                
```

**Proposed**: `80x8`, Normal mode, filesystem tree focused at the cwd after `<A-e>`

```text
  nvim.config                      │local change = {}                            
  ▾ ■ lua                          │                                             
    ▾ ■ gleb                       │                                             
      ◆ keymaps.lua                │                                             
  ▸ ■ tests                        │                                             
  ◆ init.lua                       │                                             
  README.md                        │                                             
  █ docs                           │                                             
```

The proposed state is the existing scenario's observable result: the filesystem tree has focus and no popup
or error is reported. No new screenshot scenario is needed because the exact tree contents are not behaviour.

## Risks / Trade-offs

Calling the Lua API couples the keymap to neo-tree's documented command arguments, but makes the false value
unambiguous; the Ex parser only represents the presence of the `reveal` flag. The existing integration case
guards both focus and the absence of messages.
