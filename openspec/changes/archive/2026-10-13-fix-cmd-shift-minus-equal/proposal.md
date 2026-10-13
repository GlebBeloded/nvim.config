## Why
The shortcut table says Cmd+Shift+- and Cmd+Shift+= send `\e_` / `\e+` (Alacritty `chars` bindings `key = "Minus"` / `"Equals"`, `mods = "Command|Shift"` in `terminal/alacritty/keymaps_macos.toml`) and reach Neovim as `<M-_>` / `<M-+>`. From a real key press (e2e layer, sandbox VM) Alacritty sends its kitty encoding instead (`\e[45;10u`, `\e[61;10u`) and Neovim receives `<S-D-->` / `<S-D-=>`: with Shift held the key is `_` / `+`, so the bindings never match. The chain and stack layers only check the dead bindings' bytes, so they pass. The "Known gaps" note in the spec (folding maps `<S-D-->`/`<S-D-=>` unreachable) is wrong in practice: those maps are what fires.

Kind: bug

Proposal only: the work-queue (queue-spec) writes the spec delta and design.
Open question for the user: keep today's real behaviour (drop the two dead bindings; table rows become source `kitty`, `<S-D-->` / `<S-D-=>`, folding maps reachable) or make the bindings match (`key = "_"` / `"+"`, Neovim gets `<M-_>` / `<M-+>`, then the folding maps need those keys)?

## What Changes
- `terminal/alacritty/keymaps_macos.toml`: remove or rekey the Cmd+Shift+-/= bindings.
- Shortcut table rows Cmd+Shift+- and Cmd+Shift+=, the "Known gaps" note, and the e2e scenario "Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press".
- chain layer: a `chars` binding whose key cannot match with Shift held should be reported (optional, design decides).

## Capabilities
### Modified Capabilities
- `shortcuts`: shortcut table rows Cmd+Shift+- and Cmd+Shift+=; requirement "Real key presses in the sandbox VM deliver shortcuts".

## Impact
- Code: `terminal/alacritty/keymaps_macos.toml`, possibly `tests/shortcuts/configs.py`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged in Neovim; the keys Alacritty sends for two shortcuts may change.
- Out of scope: other Shift+punctuation bindings (audit them in the same pass only if the chain check is added).

## Decision (user, 2026-10-12)
Normalize: remove the dead Alacritty bindings and anything else dead in the Alacritty ↔ zellij ↔ Neovim key path; the e2e layer (real key presses in the VM) is the source of truth for what arrives, and the shortcut table and specs follow it. Folding keeps working on what actually arrives (`<S-D-->` / `<S-D-=>`).
