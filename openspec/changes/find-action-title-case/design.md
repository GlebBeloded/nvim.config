## Current render

**Current**: `72x8`, excerpt: Find Action result rows, Normal mode, empty query, real catalog

```text
Find Action...  ⌘⇧A                                                  Help
Live grep  <A-F>                                                   Search
Open one  ⌘=                                                        Fold
Close all  ⌘⇧-                                                      Fold
Toggle filesystem  <A-e>                                           Tree
Move left  <C-h>                                                  Window
Back  gb                                                            Jump
Forward  gB                                                         Jump
```

```text
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMM
```

Legend: `B` [FindActionBody] · `M` [FindActionMetadata]

## Proposed render

**Proposed**: `72x8`, excerpt: Find Action result rows, Normal mode, empty query, approved catalog labels

```text
Open Differ  ⌘G                                               Git | Diff
Soft Wrap                                                  View | Editor
Spell Check                                                View | Editor
Find in Files...  ⌘⇧F                                        Edit | Find
Toggle File Tree  ⌘E                                 View | Tool Windows
Toggle Git Status Tree  ⌘⇧G                          View | Tool Windows
Open Diffview                                                 Git | Diff
Focus Left Window  ⌘H                                             Window
```

```text
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMSSSMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMSSSMMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMSSSMMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMSSSMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMSSSMMMMMMMMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMSSSMMMMMMMMMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMSSSMMMM
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBMMMMMM
```

Legend: `B` [FindActionBody] · `M` [FindActionMetadata] · `S` [FindActionSeparator]

The proposed render is selected because it matches `evidence/render.png`: titles are readable without category context, approved categories expose their hierarchy, and the dim separator keeps that hierarchy secondary.
