## ADDED Requirements

### Requirement: Python usage types
Python usages SHALL be classified by `queries/python/usages.scm` as `import`, `decorator`, `extends`, `instanceof`, `catch`, `keyword_argument`, `call`, `pattern`, `parameter_declaration`, `field_declaration`, `variable_declaration`, `type_alias` or `return_type`, with assignment targets captured as the `write` fallback. The target-kind rules SHALL apply, and a Python `call` of a `type` target SHALL be `new`.

#### Scenario: Python query classifies every usage type
- **WHEN** the Python `usages` query classifies each position of the case table `tests/unit/references/usage_cases/python.lua` with the installed `python` parser and the case's target kind
- **THEN** every position gets its expected catalogue type, and every negative case gets no syntactic type

#### Scenario: A Python call of a class is a new instance creation
- **WHEN** the Python query classifies `Thing` in the call of `local: Thing = Thing(key)` with target kind `type`, and again with target kind `unknown`
- **THEN** the first is `new` and the second is `call`

#### Scenario: gr classifies Python class usages
- **WHEN** Neovim runs in a fresh copy of the extended `pyproj` fixture with the cursor on the `Money` declaration in `shop/money.py`, basedpyright and ruff attached, and `gr` is pressed in normal mode
- **THEN** the view lists exactly `shop/pricing.py:1` as `import`, `shop/pricing.py:3` as `new`, `shop/pricing.py:6` as `extends`, `shop/pricing.py:10` as `parameter_declaration`, and `tests/test_pricing.py:5` as `instanceof`

#### Scenario: Python class usages are grouped by usage type
- **WHEN** `gr` is pressed on the `Money` declaration in `shop/money.py` of the extended `pyproj` fixture with basedpyright and ruff attached, the editor at 70x24 and default grouping, and classification has finished
- **THEN** the screen matches the approved render "Proposed P1 — Python usage types of a class"
