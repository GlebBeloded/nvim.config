## Context

See proposal.md (Why). Research (2026-10-16):
- **No reference kinds in LSP.** LSP 3.17/3.18 `references` returns plain `Location[]`. PR microsoft/language-server-protocol#2202 ("Queryable References", which adds `kind`) is still open.
- **documentHighlight kinds by server:**
  - **gopls:** Write covers assignment left-hand sides, `:=`, `var`/`const`, `++`/`--`, channel sends, range keys/values and struct-literal keys. Read is only given to `*types.Var`, so functions, types and packages get Text. Files that aren't open are served from disk.
  - **lua_ls:** Read/Write for locals and fields, served from the workspace file cache.
  - **basedpyright:** Write when `isWriteAccess(node)`, else Read.
  - **rust-analyzer:** uses its `ReferenceCategory` READ/WRITE.
  - **vtsls:** its documentHighlight needs an open document. `typescript.tsserverRequest` `references` returns `isWriteAccess` for every reference in a single call.
  - Only the gopls behaviour was checked against source code. For the other servers, the not-open-file behaviour was read from their source and is pinned by integration scenarios.
- **Treesitter parsers** are installed only for go, lua and bash, so the fallback covers those. Every other language relies on its server.
- **JetBrains labels:** "Value read" and "Value write" are kept as is. Every other usage is shown as "Usage".

## Goals / Non-Goals

**Goals:**
- Read/write kinds for every configured language that can supply them.
- A fallback where a parser exists.
- A level and hint that only appear when the data has kinds, and that can be toggled.

**Non-Goals:**
- Import, call and declaration usage types.
- Filters by kind.
- Installing parsers.

## Decisions

1. **Pipeline** (`kind.lua`):
   - The view opens on the references result first.
   - Usages are grouped by client and file.
   - vtsls: one tsserver request.
   - Other clients that advertise `documentHighlightProvider`: one request per file, at its first usage, with exact range matching.
   - Whatever is still unclassified goes to `kind_ts.lua`.
   - Results are cached per (uri, changedtick or file mtime).
   - `CLASSIFY_TIMEOUT_MS = 3000`.
2. **Treesitter fallback** (`kind_ts.lua`): pure write-target queries for go, lua and bash, applied only when the parser loads (`pcall(vim.treesitter.language.add, lang)`).
3. **Order and look:**
   - `Value write` comes before `Value read`, then `Usage`.
   - Write uses md-pencil (U+F03EB) in blue and read uses md-eye (U+F0208) in yellow. Each label uses the paler shade (0.7), with the groups `ReferencesWrite[Label]` and `ReferencesRead[Label]` from `icons.lua`.
4. **The hint is conditional.** `● Read/write w` only appears when a usage is read or write. Function-only views therefore keep V1–V4 unchanged, and their screenshots don't move.
5. **Level off:** row tags (`✎ write` / `◎ read`, right-aligned) keep the information visible.

## Renders

**Current**: `references-view` Proposed V1 (`openspec/changes/references-view/design.md`). There is no read/write level and no `Read/write` hint.

Stand-ins:

| Stand-in | Real glyph |
|---|---|
| `✎` | md-pencil U+F03EB (write) |
| `◎` | md-eye U+F0208 (read) |
| others | as in `references-view` |

The real-glyph, real-colour versions are `renders/kind_k1_read_write.ansi` and `renders/kind_k2_read_write_off.ansi`. View them with `command cat`.

**Proposed K1 — read/write level**: `100x30`, Normal, `report/calls.go` (extended gomod fixture), gopls attached, `gr` on `Calls` (line 4); default grouping; classification finished.

```text
▎ calls.go                                                                                          
  ╭ Usages of Calls · 4 ─────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  1                        │ report/calls.go:8                                 │  
  │   ▾ ✎ Value write  1                     │   1  package report                               │  
  │     ▾ □ report  1                        │   2                                               │  
  │         ◆ calls.go:8                     │   3  // Calls counts rendered summaries.          │  
  │ ▾ ▲ Test  3                              │   4  var Calls int                                │  
  │   ▾ ✎ Value write  1                     │   5                                               │  
  │     ▾ □ report  1                        │   6  // Count records one rendered summary.       │  
  │         ◆ calls_test.go:6                │   7  func Count() {                               │  
  │   ▾ ◎ Value read  2                      │   8      Calls++                                  │  
  │     ▾ □ report  2                        │   9  }                                            │  
  │         ◆ calls_test.go:8                │                                                   │  
  │         ◆ calls_test.go:9                │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ● Read/write w · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..
..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssffkkkkkkkfMMMMMMfffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bcccccccccGcggggggggcccccccccccccccccccccccbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffkkkfVVVVVfTTTffffffffffffffffffffffffffffffffb..
..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfsssffkkkkfHHHHHBBfBfffffffffffffffffffffffffffffffb..
..bfffffYfyyyyyyyyyyffsffffffffffffffffffffffbfrrrffffffhhhhhjjffffffffffffffffffffffffffffffffffb..
..bfffffffDfddddddffsffffffffffffffffffffffffbfsssffBffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffffGfgggggggggggggssffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `H` [@function] · `j` [@operator] · `M` [@module.go] · `V` [@variable.go] · `B` [@punctuation.bracket.go] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

**Proposed K2 — read/write level off**: `100x30`, as K1 after `w`; each usage row keeps a right-aligned write/read tag.

```text
▎ calls.go                                                                                          
  ╭ Usages of Calls · 4 ─────────────────────┬───────────────────────────────────────────────────╮  
  │ ▾ ▣ Production  1                        │ report/calls.go:8                                 │  
  │   ▾ □ report  1                          │   1  package report                               │  
  │       ◆ calls.go:8               ✎ write │   2                                               │  
  │ ▾ ▲ Test  3                              │   3  // Calls counts rendered summaries.          │  
  │   ▾ □ report  3                          │   4  var Calls int                                │  
  │       ◆ calls_test.go:6          ✎ write │   5                                               │  
  │       ◆ calls_test.go:8           ◎ read │   6  // Count records one rendered summary.       │  
  │       ◆ calls_test.go:9           ◎ read │   7  func Count() {                               │  
  │                                          │   8      Calls++                                  │  
  │                                          │   9  }                                            │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  │                                          │                                                   │  
  ├──────────────────────────────────────────┴───────────────────────────────────────────────────┤  
  │                         Tests: grouped t · ● Folders f · ○ Read/write w · Preview P · Open ↩ │  
  ╰──────────────────────────────────────────────────────────────────────────────────────────────╯  
 NORMAL  ⎇ main                                                                                  go 
```

```text
....................................................................................................
..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkkkkkfMMMMMMfffffffffffffffffffffffffffffffb..
..bcccccccGcggggggggcccccccccccccccccWcwwwwwcbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..
..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkfVVVVVfTTTffffffffffffffffffffffffffffffffb..
..bfffffffGfgggggggggggggssffffffffffWfwwwwwfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..
..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..
..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffkkkkfHHHHHBBfBfffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffhhhhhjjffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfsssffBffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..
..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..
....................................................................................................
```

Legend: `b` [PickerBorder] · `t` [MiniPickBorderText] · `f` [MiniPickNormal] · `c` [MiniPickMatchCurrent] · `s` [PickerSecondary] · `r` [CursorLineNr] · `h` [Search] · `x` [PickerHint] · `o` [PickerToggleOn] · `k` [@keyword] · `T` [@type.builtin] · `F` [@function.call] · `H` [@function] · `j` [@operator] · `M` [@module.go] · `V` [@variable.go] · `B` [@punctuation.bracket.go] · `q` [@string] · `m` [@comment] · `n` [@number] · `.` [Normal] · `P` [ReferencesProduction] · `p` [ReferencesProductionLabel] · `E` [ReferencesTest] · `e` [ReferencesTestLabel] · `D` [ReferencesFolder] · `d` [ReferencesFolderLabel] · `G` [DevIconGo] · `g` [ReferencesFileLabelDevIconGo] · `W` [ReferencesWrite] · `w` [ReferencesWriteLabel] · `Y` [ReferencesRead] · `y` [ReferencesReadLabel]

## Risks / Trade-offs

- [Server kinds disagree with treesitter] → server kinds always win; treesitter only fills gaps.
- [documentHighlight on a file that isn't open fails on some server version] → each server has an integration scenario pinning it, and a failure falls through to the fallback without an error.
- [vtsls command availability] → detected through `executeCommandProvider.commands`. When missing, vtsls goes through the documentHighlight path.
- [The extra fixture files] → `report/calls.go` and `report/calls_test.go` are tiny, and the `Format` locations are unchanged.
