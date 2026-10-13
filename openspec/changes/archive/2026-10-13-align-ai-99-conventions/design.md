# Design

## Context

See proposal.md - Why. The root cause is deliberate compatibility scope in the accepted
`refactor-ai-99-config` design: it copied the legacy `v` mappings and omitted `silent` to avoid changing
behavior, and explicitly excluded a missing-99 fallback because lazy.nvim normally invokes the setup only
after loading 99. That preserved three known exceptions to architecture rules 3.4, 3.6, and 6.1 instead
of bringing the extracted modules into convention.

The current module boundaries and setup order are otherwise correct. The change affects mapping metadata,
mode ownership, and optional-plugin wiring; it does not change screen layout, text, or color, so design
renders are not applicable.

## Goals / Non-Goals

**Goals:**
- Align the existing 99 entry points with the keymap conventions without changing their normal or visual
  actions.
- Keep the optional-plugin boundary inside the `gleb.ai` wiring entry point.
- Make each changed contract directly observable in a bare child Neovim.

**Non-Goals:**
- Reorganizing the AI modules or changing their established setup order.
- Changing keys, descriptions, prompt text, provider configuration, or prompt-buffer mappings.
- Handling failures raised after the 99 module has loaded successfully.

## Decisions

### 1. Guard 99 at the wiring boundary

`gleb.ai.setup()` will use a protected require for 99 and return immediately when the module is
unavailable. Provider and keymap modules remain untouched until that check succeeds, and successful setup
keeps the established order: configure 99, register prompt-buffer mappings, then register entry mappings.

Alternative: rely on lazy.nvim to call setup only after loading 99. Rejected because the module's public
setup function then crashes outside that one caller and remains an exception to the optional-plugin rule.

Alternative: protect every downstream require and setup call. Rejected because it would hide unrelated
configuration errors; only absence of the optional plugin is expected degradation.

### 2. Give every entry mapping its own complete conventional options

Each of the four mapping declarations will retain its current description and add `silent = true`. Keeping
the option beside each mapping makes the convention explicit despite the descriptions differing.

Alternative: introduce an options-builder helper. Rejected because four small declarations do not justify
another abstraction.

### 3. Bind selections with `x`, not `v`

The two selection actions will be registered in `x` mode. In Neovim mapping semantics, `v` covers both
Visual and Select modes, while `x` covers Visual mode only. Normal-mode mappings and the shared visual
action remain unchanged.

Alternative: retain `v` and delete the mappings from Select mode afterward. Rejected because `x` expresses
the intended ownership directly and avoids transient or duplicated mapping state.

## Risks / Trade-offs

- [A user relied on the 99 keys while in Select mode] → The spec makes default Select-mode behavior
  intentional; normal and Visual entry points remain available.
- [The protected require hides a broken installed 99 module] → Accept this at the optional-plugin boundary;
  do not wrap later setup calls, so post-load configuration failures still surface.
- [Silent metadata accidentally changes the one-key menu] → Preserve the explicit `nvim_echo` call and
  cover both mapping metadata and existing menu behavior independently.

## Migration Plan

Add focused regression coverage for the three changed contracts, then make the two localized module edits
and run the AI-focused tests plus the project gate. No data or configuration migration is required.
Rollback is a normal revert of the implementation and its spec delta; plugin state is unchanged.
