## 1. Stabilize the Terraform render assertion
Scenarios: `references: Terraform usage types match the approved render`
- [x] 1.1 Add a stable-background-highlight assertion before the screenshot in `tests/screen/references/test_view.lua`; use `FAIL in tests/screen/references/test_view.lua | references: Terraform usage types match the approved render:` with `different attr cell at line 3 column 8, reference = "3", observed = "4"` as the recorded failing evidence
- [x] 1.2 Run `make test FILE=tests/screen/references/test_view.lua CASE="references: Terraform usage types match the approved render"` and see it pass
