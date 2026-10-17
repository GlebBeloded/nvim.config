; Go usage types (ids of JetBrains GoUsageTypeProvider).
; Contract: every capture is the node whose start equals the LSP reference start.
; Precedence: when several patterns capture the same node, the pattern that
; appears first in this file wins (lowest pattern index).
; "Type reference" patterns are expanded to a type_identifier directly in the
; context or nested up to 3 levels in pure type wrappers (pointer/slice/array/map/
; chan/qualified/generic/parenthesized/~T). They never cross func, struct or
; interface types: nested signatures and fields are classified by their own
; patterns, so the innermost context wins regardless of file order.

; ---- Import --------------------------------------------------------------------
(import_spec name: (package_identifier) @usage.import)
(import_spec path: (interpreted_string_literal) @usage.import)

; ---- Type instantiation: `List[Money]`, `Sum[Money](x)` ------------------------
(type_arguments (type_elem (type_identifier) @usage.type_instantiation))
(type_arguments (type_elem (_ (type_identifier) @usage.type_instantiation))
  (#has-parent? @usage.type_instantiation pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_arguments (type_elem (_ (_ (type_identifier) @usage.type_instantiation) @_w1))
  (#has-parent? @usage.type_instantiation pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; generic call `Sum[Money](xs)` parses as a call through an index_expression;
; `fns[i](x)` parses the same way (kind-gate: keep only for type symbols)
(call_expression
  function: (index_expression index: (identifier) @usage.type_instantiation))
(call_expression
  function: (index_expression
    index: (selector_expression field: (field_identifier) @usage.type_instantiation)))

; ---- Type constraint: interface elements `~int | Money`, embedded interfaces ----
(interface_type (type_elem (type_identifier) @usage.type_constraint))
(interface_type (type_elem (_ (type_identifier) @usage.type_constraint))
  (#has-parent? @usage.type_constraint pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(interface_type (type_elem (_ (_ (type_identifier) @usage.type_constraint) @_w1))
  (#has-parent? @usage.type_constraint pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Type parameter declaration: constraint in `[T Number]` --------------------
(type_parameter_declaration type: (type_constraint (type_identifier) @usage.type_parameter_declaration))
(type_parameter_declaration type: (type_constraint (_ (type_identifier) @usage.type_parameter_declaration))
  (#has-parent? @usage.type_parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_parameter_declaration type: (type_constraint (_ (_ (type_identifier) @usage.type_parameter_declaration) @_w1))
  (#has-parent? @usage.type_parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Type assertion: `x.(T)`, `case T:` ----------------------------------------
(type_assertion_expression type: (type_identifier) @usage.type_assertion)
(type_assertion_expression type: (_ (type_identifier) @usage.type_assertion)
  (#has-parent? @usage.type_assertion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_assertion_expression type: (_ (_ (type_identifier) @usage.type_assertion) @_w1)
  (#has-parent? @usage.type_assertion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

(type_case (type_identifier) @usage.type_assertion)
(type_case (_ (type_identifier) @usage.type_assertion)
  (#has-parent? @usage.type_assertion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_case (_ (_ (type_identifier) @usage.type_assertion) @_w1)
  (#has-parent? @usage.type_assertion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Type conversion (unambiguous forms only; `T(x)` is a call) ----------------
(type_conversion_expression type: (type_identifier) @usage.type_conversion)
(type_conversion_expression type: (_ (type_identifier) @usage.type_conversion)
  (#has-parent? @usage.type_conversion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_conversion_expression type: (_ (_ (type_identifier) @usage.type_conversion) @_w1)
  (#has-parent? @usage.type_conversion pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

(call_expression
  function: (parenthesized_expression
    (unary_expression operator: "*" operand: (identifier) @usage.type_conversion)))
(call_expression
  function: (parenthesized_expression
    (unary_expression
      operator: "*"
      operand: (selector_expression field: (field_identifier) @usage.type_conversion))))

; ---- Struct initialization: `T{}`, `&T{}`, `pkg.T{}`, `G[A]{}` -----------------
(composite_literal type: (type_identifier) @usage.struct_initialization)
(composite_literal type: (qualified_type name: (type_identifier) @usage.struct_initialization))
(composite_literal type: (generic_type type: (type_identifier) @usage.struct_initialization))
(composite_literal
  type: (generic_type type: (qualified_type name: (type_identifier) @usage.struct_initialization)))

; ---- Receiver ------------------------------------------------------------------
(method_declaration receiver: (parameter_list (parameter_declaration type: (type_identifier) @usage.receiver)))
(method_declaration receiver: (parameter_list (parameter_declaration type: (_ (type_identifier) @usage.receiver)))
  (#has-parent? @usage.receiver pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(method_declaration receiver: (parameter_list (parameter_declaration type: (_ (_ (type_identifier) @usage.receiver) @_w1)))
  (#has-parent? @usage.receiver pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Parameter declaration (func, method, func literal, func type, interface method) ----
(_ parameters: (parameter_list (parameter_declaration type: (type_identifier) @usage.parameter_declaration)))
(_ parameters: (parameter_list (parameter_declaration type: (_ (type_identifier) @usage.parameter_declaration)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ parameters: (parameter_list (parameter_declaration type: (_ (_ (type_identifier) @usage.parameter_declaration) @_w1)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ parameters: (parameter_list (parameter_declaration type: (_ (_ (_ (type_identifier) @usage.parameter_declaration) @_w2) @_w1)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

(_ parameters: (parameter_list (variadic_parameter_declaration type: (type_identifier) @usage.parameter_declaration)))
(_ parameters: (parameter_list (variadic_parameter_declaration type: (_ (type_identifier) @usage.parameter_declaration)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ parameters: (parameter_list (variadic_parameter_declaration type: (_ (_ (type_identifier) @usage.parameter_declaration) @_w1)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ parameters: (parameter_list (variadic_parameter_declaration type: (_ (_ (_ (type_identifier) @usage.parameter_declaration) @_w2) @_w1)))
  (#has-parent? @usage.parameter_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Return type (unnamed result and named result list) ------------------------
(_ result: (type_identifier) @usage.return_type)
(_ result: (_ (type_identifier) @usage.return_type)
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ result: (_ (_ (type_identifier) @usage.return_type) @_w1)
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ result: (_ (_ (_ (type_identifier) @usage.return_type) @_w2) @_w1)
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

(_ result: (parameter_list (parameter_declaration type: (type_identifier) @usage.return_type)))
(_ result: (parameter_list (parameter_declaration type: (_ (type_identifier) @usage.return_type)))
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ result: (parameter_list (parameter_declaration type: (_ (_ (type_identifier) @usage.return_type) @_w1)))
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(_ result: (parameter_list (parameter_declaration type: (_ (_ (_ (type_identifier) @usage.return_type) @_w2) @_w1)))
  (#has-parent? @usage.return_type pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Field declaration (named and embedded fields) -----------------------------
(field_declaration type: (type_identifier) @usage.field_declaration)
(field_declaration type: (_ (type_identifier) @usage.field_declaration)
  (#has-parent? @usage.field_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(field_declaration type: (_ (_ (type_identifier) @usage.field_declaration) @_w1)
  (#has-parent? @usage.field_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(field_declaration type: (_ (_ (_ (type_identifier) @usage.field_declaration) @_w2) @_w1)
  (#has-parent? @usage.field_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Variable declaration: `var x T` -------------------------------------------
(var_spec type: (type_identifier) @usage.variable_declaration)
(var_spec type: (_ (type_identifier) @usage.variable_declaration)
  (#has-parent? @usage.variable_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(var_spec type: (_ (_ (type_identifier) @usage.variable_declaration) @_w1)
  (#has-parent? @usage.variable_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(var_spec type: (_ (_ (_ (type_identifier) @usage.variable_declaration) @_w2) @_w1)
  (#has-parent? @usage.variable_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Const declaration: `const c T = ...` --------------------------------------
(const_spec type: (type_identifier) @usage.const_declaration)
(const_spec type: (_ (type_identifier) @usage.const_declaration)
  (#has-parent? @usage.const_declaration pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Type alias: right side of `type A = T` and `type A T` ---------------------
(type_alias type: (type_identifier) @usage.type_alias)
(type_alias type: (_ (type_identifier) @usage.type_alias)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_alias type: (_ (_ (type_identifier) @usage.type_alias) @_w1)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_alias type: (_ (_ (_ (type_identifier) @usage.type_alias) @_w2) @_w1)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

(type_spec type: (type_identifier) @usage.type_alias)
(type_spec type: (_ (type_identifier) @usage.type_alias)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_spec type: (_ (_ (type_identifier) @usage.type_alias) @_w1)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))
(type_spec type: (_ (_ (_ (type_identifier) @usage.type_alias) @_w2) @_w1)
  (#has-parent? @usage.type_alias pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w2 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type)
  (#has-parent? @_w1 pointer_type slice_type array_type map_type channel_type qualified_type generic_type parenthesized_type negated_type))

; ---- Keyed struct field in a composite literal: JetBrains reports a write ------
(composite_literal
  type: [(type_identifier) (qualified_type) (generic_type)]
  body: (literal_value
    (keyed_element key: (literal_element (identifier) @usage.value_write))))
; elided element type: `[]T{{Amount: 1}}`
(literal_element
  (literal_value
    (keyed_element key: (literal_element (identifier) @usage.value_write))))

; ---- Call: `f()`, `pkg.F()`, `x.M()`, `go f()`, `defer f()`, `Sum[T](x)` -------
; `T(x)` and `pkg.T(x)` conversions parse identically (kind-gate: type -> type_conversion)
(call_expression function: (identifier) @usage.call)
(call_expression function: (selector_expression field: (field_identifier) @usage.call))
(call_expression function: (index_expression operand: (identifier) @usage.call))
(call_expression
  function: (index_expression
    operand: (selector_expression field: (field_identifier) @usage.call)))

; ---- Function argument: identifier or selector passed without being called -----
; syntax cannot tell a function value from a variable (kind-gate: function/method only)
(argument_list (identifier) @usage.function_argument)
(argument_list (selector_expression field: (field_identifier) @usage.function_argument))
