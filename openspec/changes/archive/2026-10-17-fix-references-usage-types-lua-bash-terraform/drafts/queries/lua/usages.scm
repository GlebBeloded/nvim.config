; Usage type of an LSP reference position: the first pattern that captures the
; identifier starting at the reference wins. @usage.write / @usage.read last.

; Computed table key `[k] = v`: the key is an ordinary read.
(field
  "["
  name: (identifier) @usage.read)

; Function declaration: function f(), local function f(), function M.f(), function M:f().
(function_declaration
  name: (identifier) @usage.function_declaration)

(function_declaration
  name: (dot_index_expression
    field: (identifier) @usage.function_declaration))

(function_declaration
  name: (method_index_expression
    method: (identifier) @usage.function_declaration))

; Function declaration by assignment: f = function, local f = function, M.f = function.
(assignment_statement
  (variable_list
    .
    name: [
      (identifier) @usage.function_declaration
      (dot_index_expression
        field: (identifier) @usage.function_declaration)
    ]
    .)
  (expression_list
    .
    value: (function_definition)
    .))

; The `function(...)` value itself: lua_ls reports it as a reference of M.f = function.
(assignment_statement
  (variable_list
    .
    name: (_)
    .)
  (expression_list
    .
    value: (function_definition) @usage.function_declaration
    .))

; Function declaration as a table field: { f = function() end }.
(field
  name: (identifier) @usage.function_declaration
  value: (function_definition) @usage.function_declaration)

; Parameter declaration in a function signature.
(parameters
  name: (identifier) @usage.parameter_declaration)

; Call: f(), f "s", f {}, M.f(), obj:m().
(function_call
  name: (identifier) @usage.call)

(function_call
  name: (dot_index_expression
    field: (identifier) @usage.call))

(function_call
  name: (method_index_expression
    method: (identifier) @usage.call))

; Table field initialisation: { total = 1 }.
(field
  name: (identifier) @usage.field_initialization)

; Write (kind_ts parity): local x = 1, local x, x = 1.
(assignment_statement
  (variable_list
    (identifier) @usage.write))

(variable_declaration
  (variable_list
    (identifier) @usage.write))

; Write (beyond kind_ts): M.x = 1, for-loop variables.
(assignment_statement
  (variable_list
    name: (dot_index_expression
      field: (identifier) @usage.write)))

(for_numeric_clause
  name: (identifier) @usage.write)

(for_generic_clause
  (variable_list
    name: (identifier) @usage.write))

; Read: every other identifier.
(identifier) @usage.read
