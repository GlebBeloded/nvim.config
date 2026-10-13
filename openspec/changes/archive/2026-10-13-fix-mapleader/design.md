## Context
See proposal.md (Why, Decision). `lazy.setup` runs inside `require("gleb.plugins")`, and diffview's `setup` (`lua/gleb/git/diffview.lua`) runs from `require("gleb.git")`, so today its keymap table holds `<leader>co` while `mapleader` is still unset (`\`); the `<D->` assignment at the end of `keymaps.lua` comes later and is not a key anyway. The four diffview conflict maps are the only `<leader>` maps in `lua/`.

Key path for a Cmd chord with no binding anywhere: Alacritty 0.17 sends its kitty flag-1 encoding, which carries the Super bit (`\e[<cp>;9u`; with Shift `;10u`). zellij 0.45 has pushed flag 1, passes unbound keys and re-encodes them for a pane that negotiated kitty keys; Neovim's TUI decodes Super as `<D-…>`. The e2e layer already observes this for Cmd+Shift+-/= (`<S-D-->`, `<S-D-=>`).

Cmd chords that never reach Neovim: Alacritty's macOS defaults (Cmd+T, N, V, C, K, M, H, Q, W, F, B, 0-9, =, +, -, Tab, Shift+[ ]), the repo's `chars` bindings (E G B Q R C / F W H J K L - = and shifted ones), the app menu (Cmd+H, Cmd+Q), and system chords (Cmd+Space, Cmd+Tab, Cmd+`, Cmd+Shift+3/4/5). The zellij config binds no `Super` key.

## Goals / Non-Goals
Goals: the leader is set before any plugin loads; every config map uses a key that reaches Neovim through Alacritty → zellij; each new chord is proven from a real key press.
Non-goals: no visible UI change (no screen output changes), so no renders. No new Alacritty binding: an unbound chord already arrives as `<D-…>`, so `terminal/` stays untouched.

## Decisions
- Leader: `vim.g.mapleader = " "` and `vim.g.maplocalleader = "\\"` as the first statements of `init.lua`, before `nvim_debug_log` and `gleb.plugins` (per the Decision). `keymaps.lua` keeps its position; its last two lines go.
- Chords, Proposed A (picked): Cmd+O ours, Cmd+I theirs ("incoming"), Cmd+D base, Cmd+A all. All four are free in every layer above, plain letters (no Shift, so Neovim receives a lowercase `<D-x>` and no Shift normalisation is involved), and mnemonic.
- Proposed B: Cmd+Shift+O/T/B/A, mirroring `co/ct/cb/ca`. Rejected: Cmd+Shift+[ ] show that Shift+Cmd changes what Alacritty matches and sends (`fix-cmd-shift-minus-equal`), and the plain chords are free.
- Proposed C: keep a two-key sequence under a single Cmd prefix (e.g. `<D-o>` then `o/t/b/a`). Rejected: the Decision asks for Cmd chords instead of leader sequences, and a sequence adds `timeoutlen` waits.
- Proposed D: Alacritty `chars` bindings sending `\eo` etc. (`<M-o>`), like the existing Cmd shortcuts (rule 3.7). Rejected: the Decision names `<D-x>` via the kitty protocol, and new bindings would add rows that zellij may decode as Alt keys it binds.
- Shortcut table: four `kitty` rows (`Cmd+O | kitty | \e[111;9u | pass | <D-o> | none`, likewise `\e[105;9u`, `\e[100;9u`, `\e[97;9u`); *Mapping* is `none` because the maps are buffer-local to diffview views. The existing chain, stack and e2e "every row" scenarios then cover them; the added scenarios also assert that no Alt or plain-letter fallback fires. The table lives outside requirement blocks, so the apply step edits it in `openspec/specs/shortcuts/spec.md` directly.
- Docs: `docs/architecture.md` load-order note says where the leader is set; rule 3.8 becomes "No `<leader>` maps in the config; Cmd shortcuts instead"; rule 3.7 adds that an unbound Cmd chord arrives as `<D-…>`.
- Tests: leader-before-lazy is checked by a `--cmd` hook that wraps `lazy.setup` through `package.preload`/`package.loaded` and records `vim.g.mapleader`. Diffview conflict scenarios use a temp git repo with a diff3 conflict (`merge.conflictStyle=diff3`) and feed `<D-o>` etc. with `nvim_input` in a full-config child (integration layer, `tests/integration/git/`).

## Risks / Trade-offs
- [`keys.swift` / the e2e denylist may lack `cmd+o/i/d/a`] → they are not system-wide chords; add them to the key helper's map only if missing.
- [A future Alacritty or macOS default takes one of the chords] → the e2e scenario fails on that row.
- [Space as leader adds `timeoutlen` waits after Space if a plugin defines `<leader>` maps] → acceptable fallback per the Decision; the config defines none.
