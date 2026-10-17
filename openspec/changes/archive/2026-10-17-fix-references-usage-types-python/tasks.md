## 1. Python query and case table

Scenarios: `references: Python query classifies every usage type`, `languages: Every configured language meets the contract`

- [x] 1.1 Write the test `references: Python query classifies every usage type` in `tests/unit/languages/test_contract.lua`, driving `gleb.references.kind_ts.classify` with the installed Python parser and the populated case table, then run `make test FILE=tests/unit/languages/test_contract.lua CASE="Python query classifies every usage type"` and see it fail because Python has no usages query
- [x] 1.2 Port the verified query to `queries/python/usages.scm`, its 157 cases and source to `tests/unit/references/usage_cases/python.lua` and `tests/unit/references/usage_cases/python/usages.py`, and set `references.usage_types = true` in `lua/gleb/languages/python/init.lua`
- [x] 1.3 Run `make test FILE=tests/unit/languages/test_contract.lua CASE="Python query classifies every usage type"` and `make test FILE=tests/unit/languages/test_contract.lua CASE="Every configured language meets the contract"` and see them pass

## 2. Python class-call refinement

Scenarios: `references: A Python call of a class is a new instance creation`

- [x] 2.1 Write the test `references: A Python call of a class is a new instance creation` in `tests/unit/references/test_kind_ts.lua`, driving the Python query and `gleb.references.kind_refine.refine_query_kind` for `type` and `unknown` targets, then run `make test FILE=tests/unit/references/test_kind_ts.lua CASE="A Python call of a class is a new instance creation"` and see it fail
- [x] 2.2 Add the Python `call` → `new` rule for a `type` target beside the Go conversion rule in `lua/gleb/references/kind_refine.lua`
- [x] 2.3 Run `make test FILE=tests/unit/references/test_kind_ts.lua CASE="A Python call of a class is a new instance creation"` and see it pass

## 3. Python class usages through gr

Scenarios: `references: gr classifies Python class usages`, `references: Python usages in production and test files`

- [x] 3.1 Write the test `references: gr classifies Python class usages` in `tests/integration/references/test_kind.lua`, driving `gr` through the real picker on the populated `pyproj` fixture at the manifest's `Money` declaration, then run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Python class usages"` and see it fail
- [x] 3.2 Extend `pyproj` in `tests/fixtures/build.sh` with the three files and `Money` manifest entry from design Decision 6, keeping every existing file and manifest entry unchanged
- [x] 3.3 Run `make test FILE=tests/integration/references/test_kind.lua CASE="gr classifies Python class usages"` and `make test FILE=tests/integration/references/test_languages.lua CASE="Python usages in production and test files"` and see them pass

## 4. Python usage-type grouping

Scenarios: `references: Python class usages are grouped by usage type`

- [x] 4.1 Write the test `references: Python class usages are grouped by usage type` in `tests/screen/references/test_view.lua`, driving `gr` through the real picker on the populated `pyproj` fixture at 70x24, then run `make test FILE=tests/screen/references/test_view.lua CASE="Python class usages are grouped by usage type"` and see it fail against the approved render
- [x] 4.2 Add the render case and reference screenshot matching “Proposed P1 — Python usage types of a class”, including the approved attribute groups
- [x] 4.3 Run `make test FILE=tests/screen/references/test_view.lua CASE="Python class usages are grouped by usage type"` and see it pass, compare `make render CASE=<python-class-usages-case>` with `renders/py_p1_class.ansi`, then run `make check`

## Agent decisions

- The Python case-table port keeps one literal descriptor table and derives raw query expectations for duplicate target-kind cases, preserving all 157 verified positions without duplicating expectations.
- The Python screen mask uses `4` for its test-only cleared background because the approved `z` symbol belongs to the New instance creation label.
