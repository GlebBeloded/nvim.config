# actions Specification

## Purpose
Defines a single action catalog and persistent shortcut source that can be queried, rebound, and invoked consistently across Neovim contexts.

## Requirements

### Requirement: Action catalog
The system SHALL register typed actions by a unique `<area>.<snake_case>` id and expose their metadata, modes, scope, availability, toggle behavior, aliases, and executable behavior without storing shortcut keys on the action.

#### Scenario: Valid actions are available by id
- **WHEN** a valid action is registered and looked up by its id or alias
- **THEN** the catalog returns that action and its metadata without shortcut data

#### Scenario: Invalid action ids are rejected
- **WHEN** an action is registered with an id outside the `<area>.<snake_case>` form
- **THEN** registration fails with an error that identifies the invalid id

#### Scenario: Duplicate action ids are rejected
- **WHEN** two actions are registered with the same id
- **THEN** registration fails with an error that identifies the duplicate id

#### Scenario: Scoped actions are filtered by context
- **WHEN** actions are queried for a mode, filetype, and invocation context
- **THEN** the result contains only actions whose modes, filetype scope, and availability predicate match that context

### Requirement: Shortcut persistence
The system SHALL read and write one JSON map from action ids to lists of Neovim lhs strings, with two-space indentation and sorted keys. Invalid input SHALL preserve the last applied bindings. Unknown action ids SHALL be warned about once and skipped.

#### Scenario: Shortcut file round-trips deterministically
- **WHEN** a shortcut map is saved and loaded
- **THEN** the loaded map equals the input and the file has two-space indentation with action ids sorted

#### Scenario: Invalid shortcut JSON preserves bindings
- **WHEN** the shortcut file cannot be decoded after bindings have been applied
- **THEN** the decode error is reported and the previously applied bindings remain

#### Scenario: Unknown action ids are skipped once
- **WHEN** the shortcut file contains an id absent from the action catalog more than once in a session
- **THEN** no binding is created for that id and exactly one warning identifies it

#### Scenario: Hidden actions cannot receive shortcuts
- **WHEN** a shortcut is assigned to a hidden action
- **THEN** the assignment is rejected and no binding is created

### Requirement: Shortcut application
The system SHALL apply configured shortcuts after `VeryLazy`. Global shortcuts SHALL be mappings in each action mode; filetype-scoped shortcuts SHALL be buffer-local mappings in matching buffers. Every mapping SHALL have description `<Category>: <Title>`.

#### Scenario: Global bindings exist after VeryLazy
- **WHEN** `VeryLazy` fires with a configured global action
- **THEN** every configured lhs is mapped in each action mode with the action description

#### Scenario: Filetype bindings are buffer-local
- **WHEN** a buffer enters an action's configured filetype
- **THEN** its shortcuts exist only in that buffer and use the action description

#### Scenario: Reapplying removes stale bindings
- **WHEN** bindings are reapplied after an lhs is removed or reassigned in the shortcut file
- **THEN** mappings previously owned by the system are removed before the current mappings are created

#### Scenario: Failed reload keeps applied bindings
- **WHEN** reapplication is requested with an unreadable or invalid shortcut file
- **THEN** all currently applied global and buffer-local bindings remain unchanged

### Requirement: Plugin mapping adapters
For plugin windows whose keys are configured during setup, the system SHALL derive the plugin's native mapping table from registered actions and current shortcuts. A runtime shortcut change SHALL take effect when that plugin window is next opened.

#### Scenario: Adapter output follows current shortcuts
- **WHEN** an adapter is requested for registered plugin-window actions
- **THEN** its native mapping table contains each current lhs and invokes the corresponding action

#### Scenario: Adapter reassignment applies on reopen
- **WHEN** a plugin-window shortcut is reassigned while its window is open and the window is reopened
- **THEN** the reopened window uses the new lhs and no longer uses the old lhs

### Requirement: Invocation context
The system SHALL capture the window, buffer, cursor, mode, and visual selection where an action was invoked. Availability, toggle, and run behavior SHALL receive that context, and execution SHALL restore the target window and visual selection when required.

#### Scenario: Invocation captures editor state
- **WHEN** an action is invoked from an editor window
- **THEN** its context identifies that window, buffer, cursor, and mode

#### Scenario: Actions run in the invocation window
- **WHEN** focus changes after context capture and the action is run
- **THEN** the action executes with the captured valid window current and its cursor restored

#### Scenario: Visual actions restore the selection
- **WHEN** a visual action is invoked after its source selection is no longer active
- **THEN** the action receives the captured context with that selection restored

#### Scenario: Availability and toggles share the context
- **WHEN** availability or toggle state is read or changed for an action
- **THEN** each operation receives the same captured invocation context as action execution

### Requirement: Shortcut capture and conflicts
The system SHALL capture chords and key sequences using Neovim key notation. Enter SHALL finish capture, Esc SHALL cancel it, and Backspace SHALL remove the last key. Exact and prefix overlaps SHALL conflict only where mode and global or filetype scope overlap.

#### Scenario: Enter finishes a normalized key sequence
- **WHEN** key input contains one or more keys followed by Enter
- **THEN** capture returns the sequence translated to Neovim key notation

#### Scenario: Esc cancels capture
- **WHEN** Esc is read during shortcut capture
- **THEN** capture returns cancellation without changing shortcuts

#### Scenario: Backspace removes the last captured key
- **WHEN** Backspace is read after multiple captured keys and capture then finishes
- **THEN** the returned sequence excludes the last key before Backspace

#### Scenario: Exact and prefix overlaps conflict in one scope
- **WHEN** a proposed lhs equals or prefixes another lhs in an overlapping mode and global or filetype scope
- **THEN** the conflict result identifies the other action and both lhs values

#### Scenario: Separate scopes do not conflict
- **WHEN** the same lhs is assigned in different modes or non-overlapping filetype scopes
- **THEN** no conflict is reported

### Requirement: Hidden Ex-command actions
The system SHALL expose unregistered Ex commands as hidden actions on demand, with humanized titles and category `Command` or `Ex`. Hidden command actions SHALL be cached for the session and SHALL not be eligible for shortcuts.

#### Scenario: Ex commands become humanized hidden actions
- **WHEN** hidden actions are requested and command completion returns `DiffviewOpen`
- **THEN** the result includes a hidden command action titled `Diffview Open`

#### Scenario: Registered commands are not duplicated
- **WHEN** a completed Ex command is already represented by a registered action
- **THEN** hidden action discovery does not add a second action for that command

#### Scenario: Hidden command discovery is cached
- **WHEN** hidden actions are requested more than once in a session
- **THEN** Ex-command completion is performed once and the same discovered actions are returned

### Requirement: Exclusive shortcut ownership
After `VeryLazy`, every global or plugin-window mapping in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t` SHALL resolve to an action id in `settings/keymap.json` or an explicit allowlist. The allowlist SHALL contain only Neovim grammar, Mason navigation, lazy.nvim view operations, autopairs insertion, codediff mouse selection, and 99's hardcoded `q` and `<CR>`. A plugin-surface open that blocks SHALL fail its test within 10 seconds with the surface name and recorded child state.

#### Scenario: Every configured mapping is action-owned
- **WHEN** the full config has fired `VeryLazy` and global mappings in modes `n`, `x`, `s`, `o`, `i`, `c`, and `t` are enumerated
- **THEN** each configured mapping resolves to one registered action and one lhs assigned to that action in `settings/keymap.json`, or is on the explicit allowlist

#### Scenario: Plugin-window mappings are action-owned
- **WHEN** neo-tree, dap-ui, diffview, differ, codediff, neotest, mason, lazy, blink, and copilot windows are opened with populated data
- **THEN** each mapping resolves to its registered action and current lhs, or exactly matches an allowlisted Mason navigation, lazy.nvim view, autopairs insertion, codediff mouse-selection, or 99 `q`/`<CR>` mapping; if a window blocks while opening, the test fails within 10 seconds with that surface's recorded child state; the blocked-open regression reports phase `opening` and live subprocess command lines, then stops its Neovim child and descendants even if the open returns before the deadline

#### Scenario: Unconfigured defaults are absent
- **WHEN** the full config has fired `VeryLazy` and Neovim and plugin mappings are enumerated
- **THEN** unadopted Neovim defaults and disabled plugin default mappings are absent

#### Scenario: Lazy specs define no shortcut keys
- **WHEN** every plugin spec returned by `lua/gleb/plugins/plugins.lua` is inspected
- **THEN** none has a `keys` field

### Requirement: Feature-owned action lists
Each feature that exposes configurable behavior SHALL define actions in its `actions.lua`; action definitions SHALL contain behavior and metadata but no lhs. Startup SHALL assemble those lists before applying `settings/keymap.json`.

#### Scenario: Feature actions contain no shortcut keys
- **WHEN** every feature `actions.lua` list registered at startup is inspected
- **THEN** every action has a valid id and behavior and none contains an lhs or shortcut field

#### Scenario: Every configured action is registered
- **WHEN** `settings/keymap.json` is loaded against the startup action catalog
- **THEN** every action id in the file resolves without an unknown-action warning
