# Find Action palette colour match

The excerpts use the same populated wide state to expose the colour and spacing differences. The approved target is the user-provided `evidence/render.png`; `evidence/impl.png` is the current live palette.

## Current render

**Current**: `76x9`, excerpt of a `100x30` screen, Normal mode, empty query, 39 matches

```text
╭ Find Action › █ ─────────────────────────────────────────────────────────╮
│ recently used ────────────────────────────────────────────────────────── │
│ Open Differ ⌘G                                                Git | Diff │
│ Soft Wrap                                                ● View | Editor │
│ other actions ────────────────────────────────────────────────────────── │
│ Find Action... ⌘⇧A                                                  Help │
├──────────────────────────────────────────────────────────────────────────┤
│                                              Assign ⌥↩ · Show hidden ⌘⇧A │
╰──────────────────────────────────────────────────────────────────────────╯
```

```text
bbpppppppppppppbcbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
nnaaaaaaaaaaaaanxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxnn
sssssssssssssseesssssssssssssssssssssssssssssssssssssssssssseeeeeeeeeess
nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnngnxxxxxxxxxxxxxnn
nnaaaaaaaaaaaaanxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxnn
nnnnnnnnnnnnnnnnnxxxnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnxxxxnn
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `p` [MiniPickPromptPrefix] · `c` [MiniPickPromptCaret] · `n` [NormalFloat] · `s` [PmenuSel] · `e` [PmenuExtraSel] · `a` [PmenuExtra] · `x` [PmenuExtra] · `g` [PmenuKind] · `h` [PickerHint]

The transparent `NormalFloat` body and background-carrying metadata groups create the dark field and patches; the hint is a separate bordered row, right-aligned and counter-free.

## Proposed render

**Proposed**: `76x8`, excerpt of a `100x30` screen, Normal mode, empty query, 39 matches

```text
╭ Find Action › █ ─────────────────────────────────────────────────────────╮
│ recently used ────────────────────────────────────────────────────────── │
│ Open Differ  ⌘G                                               Git | Diff │
│ Soft Wrap                                                ● View | Editor │
│ other actions ────────────────────────────────────────────────────────── │
│ Find Action...  ⌘⇧A                                                 Help │
│ Assign ⌥↩ · Show hidden ⌘⇧A                                        39/39 │
╰──────────────────────────────────────────────────────────────────────────╯
```

```text
bbpppppppppppppbcbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
BBaaaaaaaaaaaaaBrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrBB
SSSSSSSSSSSSSSSqqSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSaaaaaaaaaaSS
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBgBaaaaaaaaaaaaaBB
BBaaaaaaaaaaaaaBrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrBB
BBBBBBBBBBBBBBBBBBqqqBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBaaaaBB
HHHHHHHHHKKHHHHHHHHHHHHHHHKKKHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
```

Legend: `b` [FloatBorder] · `p` [FloatTitle] · `c` [MiniPickPromptCaret] · `B` [FindActionBody] · `S` [FindActionSelected] · `a` [FindActionMetadata] · `r` [FindActionRule] · `q` [FindActionShortcut] · `g` [FindActionToggleOn] · `H` [FindActionHint] · `K` [FindActionHintKey]

[FindActionBody] uses foreground `#d9c8a5` on `#45403d`; [FindActionSelected] uses `#59524d`. [FloatTitle] uses `#da8f57`. [FindActionMetadata] uses `#a59a86`; [FindActionShortcut] and [FindActionRule] use `#8f8475`. [FindActionHint] uses dim text on `#32302f`, while [FindActionHintKey] is bright. Metadata, shortcut, rule and toggle groups are foreground-only so the body or selected-row background remains continuous.

The proposed render is selected because it directly matches `evidence/render.png` and the user Decision: one frame, a darker in-frame band, applicable hints on the left, and `39/39` on the right.
