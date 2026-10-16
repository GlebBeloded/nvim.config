## Why

`references-view` is specified and tested on Go. The user wants Find Usages to work for every major language the config sets up. Each server behaves differently: some buffers have two clients attached, some servers need a project root, and some file types have no treesitter parser. So each language needs its own end-to-end proof.

Kind: feature
Depends: references-view

## What Changes

- New fixture projects in `tests/fixtures/build.sh`, one per configured language. Each has a symbol used in a production file and in a test file:
  - `luaproj` for lua_ls
  - `pyproj` for basedpyright + ruff
  - `tsproj` for vtsls + eslint
  - `rustproj` for rust-analyzer via rustaceanvim
  - `bashproj` for bashls
  - `tfproj` for terraform-ls
- For each language, an integration scenario: `gr` on the symbol opens the view with the exact usage rows and the expected Production/Test split.
- Fixes that these scenarios expose belong to this change. Examples:
  - a server that needs `includeDeclaration` handled differently;
  - a server's root detection inside the fixture.
- **No duplicates when two clients are attached** (vtsls + eslint, basedpyright + ruff): only clients that advertise `referencesProvider` are asked, and results are de-duplicated.

## Capabilities

### New Capabilities
- none.

### Modified Capabilities
- `references`: new requirement "Find Usages in every configured language", with one scenario per language plus the two-client case.

## Impact

- Code:
  - `tests/fixtures/build.sh` gains the six fixtures;
  - `lua/gleb/references/request.lua` gets whatever server-specific handling the scenarios show is needed;
  - `lua/gleb/references/scope.lua` gets pattern additions if a fixture exposes a gap.
- Tests: tests/integration/references/test_languages.lua, one case per language. Each case waits for its server through the existing readiness helpers. A case for a server the host does not have is skipped with its reason, not failed (the same policy as the readiness layer).
- Plugins: none. Core keymaps: unchanged.
- `file-tree: gr keeps its global meaning in git status tree` still holds: this change does not touch the `gr` mapping.
- Out of scope:
  - read/write kinds per language (`references-usage-kind`);
  - adding treesitter parsers. Python, TS, Rust and Terraform previews keep using Vim syntax, as their regular buffers do. Adding parsers would change every buffer and belongs in its own change.
  - HTML, CSS, JSON and YAML, where references are rarely meaningful.

## Decision (user, 2026-10-16)

- "create a spec, make sure it works for all major language in my nvim config. Split work into steps if possible"

## Agent decisions

- Major languages are the ones whose server answers references on real code: Go (already covered by `references-view`), Lua, Python, TypeScript/JavaScript, Rust, Bash and Terraform.
- Terraform has no test-file usage in its fixture, so it only checks production grouping.
- The terraform CLI is missing on the host. terraform-ls resolves references from parsed HCL without it.
