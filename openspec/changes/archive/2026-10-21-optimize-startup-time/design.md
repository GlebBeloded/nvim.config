# Design

## Context

See `proposal.md` for motivation and measured baseline. `init.lua` currently enables `vim.loader` indirectly through
`gleb.options` only after lazy.nvim has loaded startup plugins, and then eagerly requires nearly every feature module.
The action catalog and startup-sensitive session/dashboard ordering must remain available without forcing heavy feature
implementations onto the initial path.

## Goals / Non-Goals

**Goals:**

- Keep only work required for the initial editor state on the synchronous startup path.
- Preserve action IDs, keymaps, session-before-dashboard ordering, and graceful behavior when optional plugins are absent.
- Enforce the performance result through the existing isolated, warmed real-config measurement.

**Non-Goals:**

- Optimizing dependency installation, changing feature behavior, or changing anything drawn on screen.
- Adding a second plugin manager or a custom general-purpose loading framework.

## Decisions

### Enable the built-in loader before configuration modules

Enable `vim.loader` at the top of `init.lua`, before the debug log and lazy.nvim bootstrap, and remove the later call
from `gleb.options`. This applies the existing cache to the whole Lua startup path. Keeping the current placement was
rejected because it excludes plugin bootstrap and startup-plugin modules from bytecode caching.

### Use existing runtime boundaries as load triggers

Declare precise lazy.nvim `cmd`, `event`, `ft`, and dependency triggers for plugins, and attach feature setup to the
trigger that already makes the feature observable. Keep leader setup, logging, options, colors, action registration,
session restore registration, and dashboard ordering synchronous where their startup semantics require it. A blanket
defer timer was rejected because it merely moves work past the measurement and can race the first user action.

### Keep action declarations cheap

Action modules remain registered before core keymaps are usable, but callbacks require heavyweight feature code only
when invoked. This preserves stable action IDs and mappings while allowing picker, diff, PR, file-tree, LSP, testing,
and debugging implementations to remain unloaded until their real entry points run. Deferring the entire action
catalog was rejected because mappings could observe missing actions.

### Measure the real configuration

Extend the plugins integration coverage around the standard isolated full-config launcher and tighten
`make smoke-startup` to the 120 ms base budget. Both use warmed caches and real plugin data; hand-built stand-ins are
not representative of the user-visible startup path.

## Risks / Trade-offs

- [A first action can expose a missing trigger or ordering dependency] -> Exercise existing scenario tests through
  their real mappings and run the full gate after the targeted startup test.
- [Host contention makes wall-clock timing noisy] -> Keep the existing warm-up, repeated samples, retry, and host-load
  normalization.
- [Aggressive deferral can postpone startup-critical autocmd registration] -> Keep session/dashboard registration and
  other pre-`VimEnter` behavior synchronous; defer implementation work rather than required registration.
- [Lazy declarations can hide missing optional dependencies] -> Preserve protected requires and dependency metadata.

## Migration Plan

Land the loader move and trigger changes together with the tightened test. Roll back the trigger for any feature that
cannot preserve its existing scenarios without joining the startup path; the dependency lockfile requires no migration.
