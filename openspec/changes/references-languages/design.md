## Context

See proposal.md (Why). Facts checked on the host (2026-10-16):
- Mason has gopls, lua-language-server, basedpyright, ruff, vtsls, vscode-eslint-language-server, rust-analyzer, bash-language-server and terraform-ls installed.
- go, cargo/rustc, node and python3 are on PATH; the terraform CLI is not.
- Treesitter parsers exist for go, lua and bash (`lua/gleb/treesitter.lua`); python, typescript, rust and hcl/terraform have none.
- The readiness layer (`tests/integration/lsp/test_readiness.lua`) already starts gopls, basedpyright and vtsls in small fixture projects.

## Goals / Non-Goals

**Goals:** prove `gr` end to end for each configured references-capable server, with the Production/Test split, and fix what breaks.

**Non-Goals:** read/write per language (`references-usage-kind`); new treesitter parsers; HTML, CSS, JSON and YAML.

## Decisions

1. **Fixtures.** Each one is a few lines and built by `tests/fixtures/build.sh` with a manifest of usage locations, matching `gomod`:

   | Fixture | Definition | Production usage | Test usage | Root marker |
   |---|---|---|---|---|
   | `luaproj` | `lua/shop/price.lua` `M.total` | `lua/shop/cart.lua` | `spec/price_spec.lua` | `.luarc.json` |
   | `pyproj` | `shop/price.py` `total` | `shop/cart.py` | `tests/test_price.py` | `pyproject.toml` |
   | `tsproj` | `src/price.ts` `export function total` | `src/cart.ts` | `src/price.test.ts` | `package.json` and `tsconfig.json` |
   | `rustproj` | `src/price.rs` `pub fn total` (lib crate) | `src/main.rs` | `tests/price.rs` and a `#[cfg(test)] mod tests` in `src/price.rs` | `Cargo.toml` |
   | `bashproj` | `lib/price.sh` `total()` | `bin/run.sh` (sources lib) | `test/price_test.sh` | `.git` |
   | `tfproj` | `variables.tf` `variable "region"` | `main.tf`, `outputs.tf` | none | `.terraform.lock.hcl`-free module dir |

2. **Readiness.** Each case waits for its client to attach and for the first `textDocument/references` answer within the readiness bound, reusing the helpers from the readiness layer. rust-analyzer gets the longest bound, because it indexes the crate first.
3. **Skips.** When a server binary or toolchain is missing, the case is skipped with a reason, using the same `skip` path as the readiness layer. The gate stays honest and the case never passes vacuously.
4. **Two clients.** The unit scenario stubs two clients in `request.lua` (pure merge function), so de-duplication is proved without depending on eslint or ruff answering references.

## Risks / Trade-offs

- [rust-analyzer is slow to index on a cold start] → the fixture is tiny, has no dependencies, and the bound for this case is longer.
- [bashls only finds cross-file references inside its glob (`**/*@(.sh|.inc|.bash|.command)`)] → the fixture uses `.sh` files only.
- [terraform-ls without the CLI] → module references come from parsed HCL; the scenario pins that.
