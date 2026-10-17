# Generates queries/go/usages.scm. Type wrappers are expanded to fixed depths
# because tree-sitter queries have no descendant operator.
W = "pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type"

def tref(head, cap, depth=3, close=")"):
    """Patterns capturing a type_identifier at `head` (an open S-expression prefix
    ending right before the type node) directly or nested in up to `depth` wrappers."""
    c = f"@usage.{cap}"
    out = [f"{head}(type_identifier) {c}{close}"]
    if depth >= 1:
        out.append(f"{head}(_ (type_identifier) {c}){close}\n  (#has-parent? {c} {W}))")
    if depth >= 2:
        out.append(f"{head}(_ (_ (type_identifier) {c}) @_w1){close}\n  (#has-parent? {c} {W})\n  (#has-parent? @_w1 {W}))")
    if depth >= 3:
        out.append(f"{head}(_ (_ (_ (type_identifier) {c}) @_w2) @_w1){close}\n  (#has-parent? {c} {W})\n  (#has-parent? @_w2 {W})\n  (#has-parent? @_w1 {W}))")
    # depth>=1 patterns end with the predicate block: move the outer close before predicates
    fixed = []
    for p in out:
        if "#has-parent?" in p:
            body, preds = p.split("\n", 1)
            # body ends with `{close}`; outer parens must wrap predicates too
            body = body[: -len(close)] if close else body
            fixed.append(body + close[:-1] + "\n" + preds[:-1] + ")" if close else body + "\n" + preds)
        else:
            fixed.append(p)
    return "\n".join(fixed) + "\n"

def section(title):
    return f"\n; ---- {title} " + "-" * max(4, 74 - len(title)) + "\n"

q = []
q.append("""; Go usage types (ids of JetBrains GoUsageTypeProvider).
; Contract: every capture is the node whose start equals the LSP reference start.
; Precedence: when several patterns capture the same node, the pattern that
; appears first in this file wins (lowest pattern index).
; "Type reference" patterns are expanded to a type_identifier directly in the
; context or nested up to 3 levels in pure type wrappers (pointer/slice/array/map/
; chan/qualified/generic/parenthesized/~T). They never cross func, struct or
; interface types: nested signatures and fields are classified by their own
; patterns, so the innermost context wins regardless of file order.
""")
q.append(section("Import"))
q.append("(import_spec name: (package_identifier) @usage.import)\n(import_spec path: (interpreted_string_literal) @usage.import)\n")

q.append(section("Type instantiation: `List[Money]`, `Sum[Money](x)`"))
q.append(tref("(type_arguments (type_elem ", "type_instantiation", 2, "))"))
q.append("""
; generic call `Sum[Money](xs)` parses as a call through an index_expression;
; `fns[i](x)` parses the same way (kind-gate: keep only for type symbols)
(call_expression
  function: (index_expression index: (identifier) @usage.type_instantiation))
(call_expression
  function: (index_expression
    index: (selector_expression field: (field_identifier) @usage.type_instantiation)))
""")

q.append(section("Type constraint: interface elements `~int | Money`, embedded interfaces"))
q.append(tref("(interface_type (type_elem ", "type_constraint", 2, "))"))

q.append(section("Type parameter declaration: constraint in `[T Number]`"))
q.append(tref("(type_parameter_declaration type: (type_constraint ", "type_parameter_declaration", 2, "))"))

q.append(section("Type assertion: `x.(T)`, `case T:`"))
q.append(tref("(type_assertion_expression type: ", "type_assertion", 2, ")"))
# no `type:` field here: tree-sitter only matches the field on the first case type
q.append("\n" + tref("(type_case ", "type_assertion", 2, ")"))

q.append(section("Type conversion (unambiguous forms only; `T(x)` is a call)"))
q.append(tref("(type_conversion_expression type: ", "type_conversion", 2, ")"))
q.append("""
(call_expression
  function: (parenthesized_expression
    (unary_expression operator: "*" operand: (identifier) @usage.type_conversion)))
(call_expression
  function: (parenthesized_expression
    (unary_expression
      operator: "*"
      operand: (selector_expression field: (field_identifier) @usage.type_conversion))))
""")

q.append(section("Struct initialization: `T{}`, `&T{}`, `pkg.T{}`, `G[A]{}`"))
q.append("""(composite_literal type: (type_identifier) @usage.struct_initialization)
(composite_literal type: (qualified_type name: (type_identifier) @usage.struct_initialization))
(composite_literal type: (generic_type type: (type_identifier) @usage.struct_initialization))
(composite_literal
  type: (generic_type type: (qualified_type name: (type_identifier) @usage.struct_initialization)))
""")

q.append(section("Receiver"))
q.append(tref("(method_declaration receiver: (parameter_list (parameter_declaration type: ", "receiver", 2, ")))"))

q.append(section("Parameter declaration (func, method, func literal, func type, interface method)"))
q.append(tref("(_ parameters: (parameter_list (parameter_declaration type: ", "parameter_declaration", 3, ")))"))
q.append("\n" + tref("(_ parameters: (parameter_list (variadic_parameter_declaration type: ", "parameter_declaration", 3, ")))"))

q.append(section("Return type (unnamed result and named result list)"))
q.append(tref("(_ result: ", "return_type", 3, ")"))
q.append("\n" + tref("(_ result: (parameter_list (parameter_declaration type: ", "return_type", 3, ")))"))

q.append(section("Field declaration (named and embedded fields)"))
q.append(tref("(field_declaration type: ", "field_declaration", 3, ")"))

q.append(section("Variable declaration: `var x T`"))
q.append(tref("(var_spec type: ", "variable_declaration", 3, ")"))

q.append(section("Const declaration: `const c T = ...`"))
q.append(tref("(const_spec type: ", "const_declaration", 1, ")"))

q.append(section("Type alias: right side of `type A = T` and `type A T`"))
q.append(tref("(type_alias type: ", "type_alias", 3, ")"))
q.append("\n" + tref("(type_spec type: ", "type_alias", 3, ")"))

q.append(section("Keyed struct field in a composite literal: JetBrains reports a write"))
q.append("""(composite_literal
  type: [(type_identifier) (qualified_type) (generic_type)]
  body: (literal_value
    (keyed_element key: (literal_element (identifier) @usage.value_write))))
; elided element type: `[]T{{Amount: 1}}`
(literal_element
  (literal_value
    (keyed_element key: (literal_element (identifier) @usage.value_write))))
""")

q.append(section("Call: `f()`, `pkg.F()`, `x.M()`, `go f()`, `defer f()`, `Sum[T](x)`"))
q.append("""; `T(x)` and `pkg.T(x)` conversions parse identically (kind-gate: type -> type_conversion)
(call_expression function: (identifier) @usage.call)
(call_expression function: (selector_expression field: (field_identifier) @usage.call))
(call_expression function: (index_expression operand: (identifier) @usage.call))
(call_expression
  function: (index_expression
    operand: (selector_expression field: (field_identifier) @usage.call)))
""")

q.append(section("Function argument: identifier or selector passed without being called"))
q.append("""; syntax cannot tell a function value from a variable (kind-gate: function/method only)
(argument_list (identifier) @usage.function_argument)
(argument_list (selector_expression field: (field_identifier) @usage.function_argument))
""")
open("queries/go/usages.scm", "w").write("".join(q))
