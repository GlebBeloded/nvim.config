## Why

There is no way to see every action, find one by name, see its shortcut, or bind a key to it while working. The user wants a GoLand-style "Find Action" on Cmd+Shift+A that becomes the main entry point to editor and plugin actions, with shortcuts assignable at runtime.

Kind: feature
Depends: action-registry, picker-ui

## What Changes

- New `lua/gleb/find_action/`: the Find Action palette, built on the `picker` frame over the `actions` registry.
- **Open:**
  - Cmd+Shift+A opens the palette, through a new Alacritty binding and a new shortcut-table row.
  - The palette is also an action itself (`find_action.open`, "Find Action...").
- **Rows:**
  - The title comes first. The physical shortcut label (`⌘G`, `⌘⇧F`, `⌃↩`, or Vim notation when there is no physical label) follows right after it in a dimmer grey. Only the first lhs is shown.
  - The category is right-aligned (`Git | Diff`).
  - There is no icon column.
  - Toggles show `●` (green, on) or `○` (grey, off) before the category, with no ON/OFF text. Enter flips a toggle and the palette stays open on the same row.
- **Ordering:**
  - An empty query shows "recently used" (saved across sessions) and then the curated actions.
  - A query does fuzzy matching on title, category and aliases.
- **Hidden items:**
  - Ex commands, and actions that are unavailable because `when` is false or the `ft` scope does not match, are hidden by default.
  - "Show hidden" (pressing Cmd+Shift+A again inside the palette) lists them below a `More results` separator. Unavailable actions stay hidden unless "Show hidden" is on.
- **Run:**
  - Running an action closes the palette and does exactly what its shortcut would have done where the palette was opened. It uses the `actions` context: window, buffer, cursor, mode and visual selection.
  - Opening the palette from visual mode lists only `x`-mode actions and keeps the selection.
- **Assign Shortcut (Option+Return, which arrives as `<M-}>`):**
  - A small float shows the keys pressed so far, which accepts chords and sequences. Enter saves and Esc cancels.
  - A conflict lists the actions that already use the key, with Remove other / Keep both / Cancel buttons.
  - Saving writes `settings/keymap.json` and re-applies the bindings immediately. Keys handled by a plugin adapter show "applies when <plugin> reopens".
  - Hidden Ex commands cannot be assigned.
- **Hint row** (picker frame): `Assign ⌥↩ · Show hidden ⌘⇧A`, right-aligned. There is no Remove: removing shortcuts belongs to a later shortcuts screen.
- **Small windows:** the picker breakpoints apply. Below 48 columns the rows show titles only.
- **Removed:** the 99 echo-prompt menu on Cmd+9 (`normal_menu`). Its two actions, 99 Search and 99 Vibe, become registry actions.

## Capabilities

### New Capabilities
- `find-action`: the palette's contents, ordering, hidden tier, toggles, running in context, the assign-shortcut flow, and the hint row texts.

### Modified Capabilities
- `shortcuts`: a new Cmd+Shift+A row (Alacritty binding, zellij pass, Neovim key, mapping `find_action.open`), checked by chain, stack and e2e.
- `ai`: the `<A-9>` menu is removed; 99 actions are registered instead.

## Impact

- Code:
  - New: `lua/gleb/find_action/`.
  - Changed: `terminal/alacritty` (Cmd+Shift+A binding), `lua/gleb/ai/entry_keymaps.lua`, `settings/keymap.json` (adds `find_action.open`).
- **Tests.** The user asked for a full suite with visual verification, because the logic is complex:
  - **Unit:** ordering (recently used, curated, the hidden separator), the label mapping (lhs → physical label), and the conflict and choice outcomes.
  - **Integration, generated over every registered action:**
    - the action is listed with its title, category and shortcut label;
    - running it from the palette has the same effect as pressing its key in the same fixture context;
    - toggles flip in the window the palette was opened from, and the palette stays open.
  - **Screen:** reference screenshots for the empty query, a query, toggles, show hidden, the assign float with and without a conflict, the 3 width breakpoints and visual-mode open. The approved renders in design.md become these references.
  - **Stack:** real zellij. Cmd+Shift+A bytes open the palette. `<M-}>` assigns a shortcut. The new key works, and it still works after restarting Neovim.
  - **E2E (sandbox VM):**
    - real key presses: open, search, run, assign by pressing physical keys, use the new key, restart, use it again;
    - each step's screen (zellij dump) is compared with its approved render.
- Plugins: none added beyond `picker-ui`. Core keymaps: **adds Cmd+Shift+A** and **removes Cmd+9 (99 menu)**.
- Out of scope:
  - tabs / Search Everywhere;
  - a shortcuts editor (remove or reset);
  - abbreviations;
  - code-search menus.

## Decision (user, 2026-10-14)

- Layout A (centered), single window, with title and query in the top border. Inside, the S1 style: section headers, the dim shortcut right after the title, the category on the right, and toggle glyphs (grey/green) instead of ON/OFF text.
- Hint row H1: a joined rule above the hints, which are right-aligned, with no count and no Remove ("we will have shortcuts screen later").
- Hidden items: below a separator and hidden by default. Unavailable actions are always hidden until "show hidden".
- Shortcut label: physical (`⌘G`) only, first shortcut only. The empty query shows recently used, then curated actions.
- Assign UI: a float with keys, conflicts and buttons.
- A full e2e suite with visual verification: "This is very important, since it's complex logic".
- Cmd+Shift+A: add the Alacritty binding (shortcut table).
