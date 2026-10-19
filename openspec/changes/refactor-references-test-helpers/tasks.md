## 1. Extract reference-readiness helpers and migrate render cases
Scenarios: `references: TypeScript class usages are grouped by usage type`, `references: Python class usages are grouped by usage type`, `references: Lua usage types match the approved render`, `references: Bash usage types match the approved render`, `references: Terraform usage types match the approved render`
- [x] 1.1 Run `make test FILE=tests/screen/references/test_view.lua CASE="TypeScript class usages are grouped by usage type"`, the equivalent commands for the other four scenarios, and `make render CASE=<ts_p1_class|py_p1_class|lua_l1_apply|bash_b1_rate|terraform_h1_vpc>` and see them pass; add typed `H.wait_references_ready`, `H.watch_rust_quiescent`, and `H.wait_rust_quiescent` helpers in `tests/helpers.lua`, replace the five readiness loops in `tests/render/cases.lua` without changing their minimums, consecutive passes, waits, or bounds, then run the same commands again and see them pass

## 2. Migrate non-Rust screen readiness loops
Scenarios: `references: TypeScript class usages are grouped by usage type`, `references: Python class usages are grouped by usage type`, `references: Lua usage types match the approved render`, `references: Bash usage types match the approved render`, `references: Terraform usage types match the approved render`
- [x] 2.1 Run `make test FILE=tests/screen/references/test_view.lua CASE="TypeScript class usages are grouped by usage type"` and the equivalent commands for the other four scenarios and see them pass, replace their copied readiness loops with `H.wait_references_ready` while preserving every assertion, wait, minimum, and bound, then run the same commands again and see them pass

## 3. Migrate Rust screen readiness and quiescence
Scenarios: `references: Rust struct usages are grouped by usage type`
- [ ] 3.1 Run `make test FILE=tests/screen/references/test_view.lua CASE="Rust struct usages are grouped by usage type"` and see it pass, replace the Rust handler wrapping and readiness loop with the shared helpers while preserving restoration, assertions, waits, minimums, and bounds, then run it again and see it pass

## 4. Migrate language integration readiness and quiescence
Scenarios: `references: Lua usages in production and spec files`, `references: Python usages in production and test files`, `references: TypeScript usages in production and test files`, `references: Rust usages in production and test code`, `references: Terraform variable usages`
- [ ] 4.1 Run `make test FILE=tests/integration/references/test_languages.lua CASE="Lua usages in production and spec files"` and the equivalent commands for the other four scenarios and see them pass, replace the shared language readiness loop and Rust handler wrapping with the new helpers while preserving one-pass readiness, error capture, restoration, assertions, waits, and bounds, then run the same commands again and see them pass

## 5. Migrate kind and classification integration helpers
Scenarios: `references: gr classifies every Go variable usage`, `references: gopls kinds classify a Go variable`, `references: rust-analyzer kinds classify a Rust variable`
- [ ] 5.1 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies every Go variable usage"` and the equivalent commands for the other two scenarios and see them pass, replace the copied readiness, content-modified retry, optional document-highlight request, and Rust quiescence handling with the shared helpers while preserving every assertion, wait, retry condition, request method, minimum, and bound, then run the same commands again and see them pass

## Agent decisions

- The readiness options include request method, content-modified retry, error capture, and origin filtering so later migrations can preserve their existing variants without callback hooks.
