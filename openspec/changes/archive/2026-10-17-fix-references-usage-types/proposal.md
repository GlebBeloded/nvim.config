## Why

Kind: bug

Find Usages only tells a variable's writes from its reads. Every other usage is a bare `Usage` row, and for functions and types the level disappears entirely. GoLand classifies each usage by its syntactic context: `Struct initialization`, `Field declaration`, `Parameter declaration`, `Return type`, `Receiver`, `Call`, `Import` and so on, with 16 Go types. The user wants that observability for every configured language.

## Evidence

- `gr` on `Invoice` (gomod fixture, `billing/invoice.go:6`) lists `Production` → `billing` → `invoice.go:11`, `invoice.go:20` with no type level. GoLand shows the same usages under `Receiver`.
- The user's GoLand screenshot shows "Usages in All Places → Production → Field declaration 1 · Parameter declaration 6 · Return type 7 · Struct initialization 4 · Unclassified 1".
- `lua/gleb/references/kind.lua` only produces `write`/`read`/`other`, and `tree.lua` only groups `Value write`, `Value read` and `Usage`.
- GoLand's own classifier (`com.goide.usages.GoUsageTypeProvider` and the `go.usage.type.*` strings in the local GoLand install's `GoBundle.properties`) checks the reference's parent nodes. Its types are:
  - Call, Const declaration, Field declaration, Function argument, Import
  - Parameter declaration, Receiver, Return type, Struct initialization
  - Type alias, Type assertion, Type constraint, Type conversion, Type instantiation, Type parameter declaration, Variable declaration
  - Value read and Value write, which come from the platform's read/write detector.
- The platform rule (`UsageTypeGroupingRule`), in order:
  1. A usage inside a comment is "Usage in comments".
  2. Otherwise the language provider's first match wins.
  3. Otherwise read/write access decides.
  4. Otherwise the usage is "Unclassified".
  Groups are sorted by their display text.

## What Changes

- **Usage type model.** Every usage gets one id from a usage type catalogue (`lua/gleb/references/usage_types.lua`).
  - Each id has a JetBrains-worded label, a Nerd Font icon, an icon colour and a short tag (design.md, Catalogue).
  - `write` and `read` stay as they are. `other` becomes `unclassified`.
  - The catalogue holds the ids of every configured language, so the later language changes only add queries.
- **Classification order,** as in JetBrains:
  1. The syntactic type that the filetype's `queries/<lang>/usages.scm` captures at the usage's start (lowest pattern index wins), refined by the target's kind.
  2. Server write/read, as today.
  3. The query's `@usage.write`/`@usage.read` fallback.
  4. `unclassified`.
- **Target kind refinement.** The existing definition + documentSymbol lookup (today only "is it callable") now returns `function`, `type`, `field`, `variable` or `unknown`:
  - Function and type targets never get write/read.
  - `function_argument` needs a function target.
  - Go `T(x)` is a `type_conversion` for a type target and a `call` otherwise.
  - Type-position types are dropped for a known non-type target.
- **Go query:** `queries/go/usages.scm` covers all 16 GoLand types, plus keyed composite-literal fields as `write`. The verified draft is in `drafts/`.
- **Treesitter fallback moves to query files.** `kind_ts.lua` becomes a generic `usages` query runner. Its inline Lua, Bash and HCL write/read queries move unchanged into `queries/{lua,bash,hcl}/usages.scm` (terraform inherits hcl).
- **Tree.** A `Usage type` level replaces the read/write level, between test scope and folder.
  - Groups are sorted by label in JetBrains string order.
  - The level and its hint appear when at least one usage is not `unclassified`.
  - Icons come from the catalogue, and labels use the 0.7 paler shade.
- **Toggle.**
  - `u` (`references.toggle_usage_type`, replacing `references.toggle_read_write` on `w`) toggles the level.
  - The hint shows `●`/`○ Usage type u`.
  - The state persists as `usage_type`. A persisted `read_write` is read once as its value.
  - With the level off, each typed usage row carries a right-aligned tag: the type's icon and short name.
- **Fixture.** The `gomod` fixture gains `billing/batch.go` and `billing/invoice_test.go` (usages of `Invoice` in every common position) and an `Invoice` manifest entry.
- **Renders.** V1–V4, K1 and K2 are refreshed: `Format` usages now sit under `Call`, value groups sort `Value read` before `Value write`, and the hint reads `Usage type u`. T1 and T2 (struct usage types) are new.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `references`:
  - Removed: "Read/write grouping" and "Read/write toggle". They are replaced by the added "Usage type grouping" and "Usage type toggle"; write and read become two usage types and `w` becomes `u`. This is a breaking change for the K1/K2 tests, which move to the new scenarios.
  - Renamed and modified: "Usage kind classification" → "Usage type classification".
  - Modified: "Find Usages in every configured language", whose per-language scenarios no longer depend on which type groups appear. Also modified: layout, tree grouping, grouping controls, navigation keys and asynchronous classification, which pick up the new level, renders and key.
  - Added: "Usage type catalogue" and "Target kind refines usage types".

## Impact

- Code:
  - New: `lua/gleb/references/usage_types.lua`, `queries/go/usages.scm`, `queries/{lua,bash,hcl,terraform}/usages.scm`.
  - Changed: `kind.lua` and `kind_ts.lua` (classification order, target kind, query runner), `tree.lua`, `icons.lua`, `view.lua`, `actions.lua`, `state.lua`, `settings/keymap.json` (`references.toggle_usage_type` on `u`).
- Tests:
  - unit:
    - the catalogue covers every query capture, and groups sort by label;
    - the Go query passes the draft case table with the real `go` parser;
    - target-kind refinement;
    - the tree level and tags;
    - state migration.
  - integration: gopls `gr` on `Invoice`, `Format` and `Lines` in the extended `gomod` fixture.
  - screen: V1–V4, K1, K2, T1 and T2.
  - e2e: the K1→K2 real-key test now presses `u`.
- Plugins: none. Core keymaps: none (`u` is buffer-local to the view filetype).
- Unchanged scenarios:
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping and its callback are untouched; only the view's classification and buffer-local keys change.
  - `references: Terraform variable usages` still holds: it names no type rows.
- Out of scope:
  - Type queries for TypeScript/JavaScript, Python, Rust, Lua, Bash and Terraform (the follow-up changes `fix-references-usage-types-typescript`, `-python`, `-rust` and `-lua-bash-terraform`).
  - "Usage in comments" and "Usage in string constants": servers don't return those locations.
  - Filtering by type, and a function level.

## Decision (user, 2026-10-17)

- "it is implemented, but lacking. Goland system is ALOT reacher. For example: struct initialization, struct field. Field declaration, Func param declaration … I want goland-like observability over references, which is sueprior. … create a spec to fix it for all langauges."
- "create a bug in queue". The user drains the queue with `make drain`.

## Decision (auditor, 2026-10-17, test integrity)

- Every screen case in tests/screen/references/test_view.lua keeps checking its whole colour mask (every row of the float, as before this change), never a single row; mask rows for new or changed renders come from real captures with one legend letter per highlight group named in the legend, and the preview rows keep the regular buffer's syntax groups.
- A screenshot comparison a test had (e.g. the hidden → mixed → grouped round trip) stays a screenshot comparison; it is never replaced by text `find()` checks.

## Agent decisions

- **Labels:**
  - One catalogue with GoLand wording for every language. Where JetBrains words the same idea differently per language, GoLand's label wins: "Type instantiation" for generic arguments, "Call" for function calls.
  - Ideas GoLand has no label for use JetBrains' platform or Kotlin wording: "New instance creation", "Supertype", "Type check", "Type cast".
- **Order:** groups are alphabetical by label, as in JetBrains, so `Value read` now precedes `Value write`.
- **Key:** `u`, mnemonic for the JetBrains toolbar's "Usage Type". Keys stay rebindable in `settings/keymap.json`.
- **Function views:** a view whose usages are all calls still shows one `Call` group, as GoLand does.
- **Icons:** the colours group types by family (design.md, Catalogue). The user may adjust them before draining.
