## 1. Python query and case table

Scenarios: `references: Python query classifies every usage type`, `references: A Python call of a class is a new instance creation`

- [ ] 1.1 Port `drafts/expected.lua` into `tests/unit/references/usage_cases/python.lua` (shared driver format) and `drafts/fixtures/usages.py` into `tests/unit/references/usage_cases/python/usages.py`. Add the two scenarios to the shared case driver from `languages-registry`, run its file with `make test FILE=…`, and see them fail: no Python query exists.
- [ ] 1.2 Add `queries/python/usages.scm` from `drafts/queries/python/usages.scm`. It already uses catalogue ids (design Decision 1). Leave the shared and inherited query files untouched.
- [ ] 1.3 Add the Python `call` → `new` rule for a `type` target next to the Go `call` → `type_conversion` rule in the target-kind refinement of `lua/gleb/references/kind.lua` (design Decision 4).
- [ ] 1.4 Set `references.usage_types = true` in `lua/gleb/languages/python/init.lua`, replacing `{ disabled = "queued: fix-references-usage-types-python" }`. Check that `languages: Every configured language meets the contract` passes, and that `references: Every query capture is in the catalogue` still passes.
- [ ] 1.5 Run the case driver and see all 157 cases pass. Every draft case must pass; a restructured query keeps them all green.

## 2. Fixture and gr integration

Scenarios: `references: gr classifies Python class usages`

- [ ] 2.1 Write the scenario in `tests/integration/references/test_kind.lua`, opening the extended `pyproj` fixture on the manifest's first `Money` location, and see it fail.
- [ ] 2.2 Extend `pyproj` in `tests/fixtures/build.sh` with `shop/money.py`, `shop/pricing.py` and `tests/test_pricing.py` exactly as in design Decision 6. Add them to the `py_compile` line and add the `Money` manifest entry (`identifier_locations Money shop/money.py shop/pricing.py tests/test_pricing.py`). Existing files and the `total` entry stay byte-identical.
- [ ] 2.3 Run `make test FILE=tests/integration/references/test_kind.lua` and `make test FILE=tests/integration/references/test_languages.lua`, and see the new scenario and every existing Python scenario pass.

## 3. Screen

Scenarios: `references: Python class usages are grouped by usage type`

- [ ] 3.1 Write the scenario in `tests/screen/references/test_view.lua` at 70x24, with real glyphs where the render has stand-ins and attribute blocks per the mask groups. Add a `tests/render/cases.lua` case for `make render`. See the screen test fail.
- [ ] 3.2 Run `make test-screen`, review the new reference screenshot against "Proposed P1 — Python usage types of a class", and compare `make render CASE=<case>` with `renders/py_p1_class.ansi`.
- [ ] 3.3 Run `make trace` and see all four scenarios of this change listed as tested, then run `make check` and see it green.
