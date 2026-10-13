# Design

## Context

Root cause (see proposal.md, Why): since Alacritty 0.13 a binding matches the *logical* key of the press, and with Shift held on a US layout Minus/Equals produce `_`/`+`. `key = "Minus"` / `key = "Equals"` with `mods = "Command|Shift"` therefore never match, so Alacritty falls back to its own kitty flag-1 encoding (`\e[45;10u`, `\e[61;10u`; zellij has pushed the flag). zellij leaves both unbound and re-encodes them for the kitty-aware Neovim pane, which decodes `<S-D-->` / `<S-D-=>`, exactly the keys `lua/gleb/folding` maps to `closeAllFolds` / `openAllFolds`. Letter keys are not affected: Alacritty compares letters case-insensitively, which the e2e layer confirms for Cmd+Shift+Q/F/W/H/J/K/L and Option+Shift+H/J/K/L.

The chain layer only compares binding bytes with table bytes, so a binding that can never fire looks healthy there and in the stack layer (which feeds bytes, not key presses).

No visible UI: only the bytes behind two shortcuts change; nothing on screen differs, so no renders.

## Goals / Non-Goals

**Goals:**
- The shortcut table, the Alacritty config and the e2e layer agree for Cmd+Shift+- and Cmd+Shift+=.
- The chain layer catches a `chars` binding that can never fire, so the class of bug cannot come back silently.

**Non-Goals:**
- Cmd+Q, Cmd+H, Cmd+Shift+Q: owned by `fix-cmd-q-shortcut`; their exceptions stay as they are here.
- Changing Neovim folding maps or adding `<M-_>` / `<M-+>` maps.

## Decisions

1. **Remove the two bindings, keep Alacritty's kitty encoding** (user decision, proposal). Alternative rejected by the user: rekey to `key = "_"` / `"+"` so Neovim gets `<M-_>` / `<M-+>` and remap folding.
2. **Table rows become `kitty`**: Cmd+Shift+- → `\e[45;10u`, pass, `<S-D-->`, fn `require("ufo").closeAllFolds`; Cmd+Shift+= → `\e[61;10u`, pass, `<S-D-=>`, fn `require("ufo").openAllFolds`. The chain already computes kitty bytes and decodes `CSI … u`, so no chain code should be needed beyond confirming those cells; if the decoder lacks the super bit (8) or the mapping cell cannot resolve `ufo` callbacks, fix the decoder/resolver, not the table. The "Known gaps" sentence about Cmd+Shift+-/= is dropped. The table and Known gaps live outside the requirement blocks, so they are edited in `openspec/specs/shortcuts/spec.md` directly in this change.
3. **Dead-binding check in the chain** (scenario "Every Alacritty chars binding can match a key press"): flag any non-Vi `chars` binding whose mods contain `Shift` and whose key is a named non-letter character key (Alacritty names for US punctuation and digits: `Minus`, `Equals`, `Slash`, `Backslash`, `LBracket`, `RBracket`, `Semicolon`, `Apostrophe`, `Comma`, `Period`, `Grave`, `Key0`–`Key9`). Non-character keys (`Return`, `Tab`, arrows, `F1`…) and letters stay valid. A static list is enough for a single-user US-layout config; checking against the real layout would need macOS APIs the chain does not have. Alternative rejected: only rely on e2e, which runs only in the VM and not in `make check`.
4. **e2e**: drop Cmd+Shift+-/= from `OWN_CASE`, so the generic "Every passed shortcut …" case presses them; keep the dedicated scenario (it also proves the stale `<M-_>`/`<M-+>` never fire) and add a fold scenario proving the user-visible effect.

## Risks / Trade-offs

- [Kitty encoding depends on zellij pushing the kitty flag] → already true for Ctrl+H/L/Q/Return/arrow rows; the stack scenario "Ctrl+Return reaches Neovim through the kitty keyboard protocol" guards it.
- [Static key list misses a punctuation key added later] → the check reports bindings by key name, so adding a name is a one-line change; e2e still catches it.
- [Outside zellij (plain Alacritty without the kitty flag) Cmd+Shift+-/= send nothing useful] → accepted; the table describes the zellij path only.
