# Proposal

## Why

`:'<,'>Gitlink` currently loses the Ex command's end line after Visual mode exits, so a selected range such as lines 3–5 is copied as `#L3-L3`. The existing `git` capability already requires the exact selected range to be preserved.

## What Changes

- Forward the explicit `:Gitlink` command range so the generated permalink spans exactly `line1` through `line2`.
- Remove the stale comment suggesting a local patch to gitlinker.nvim.
- Add headless regression coverage for the existing `Gitlink copies range URL` scenario.
- No plugin dependency is added, removed, or upgraded.
- No core keymap changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `git`: Clarify that ranged `:Gitlink` uses the Ex command's explicit inclusive endpoints.

## Impact

The change is limited to the Gitlink command adapter in `lua/gleb/git/gitlink.lua`, its headless Git integration coverage, and the `git` capability delta. It does not patch or rewire gitlinker.nvim, change non-range permalink behavior, alter URL formats, or affect other Git integrations.
