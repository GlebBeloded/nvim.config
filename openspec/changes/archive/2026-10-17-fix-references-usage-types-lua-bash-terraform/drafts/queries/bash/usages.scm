; Usage type of an LSP reference position: the first pattern that captures a
; node starting at the reference wins. @usage.write / @usage.read last.

; Function declaration: f() { }, function f { }.
(function_definition
  name: (word) @usage.function_declaration)

; Call: the command name (a function invocation when the reference is a function).
(command
  name: (command_name
    (word) @usage.call))

; Export without a value: export x.
(declaration_command
  "export"
  (variable_name) @usage.export)

; Write (kind_ts parity): x=1, local x=1, export x=1, readonly x=1.
(variable_assignment
  name: (variable_name) @usage.write)

; Write (beyond kind_ts): arr[0]=v, declare x, local x, for x in, read x, (( x++ )).
(variable_assignment
  name: (subscript
    name: (variable_name) @usage.write))

(declaration_command
  [
    "declare"
    "typeset"
    "local"
  ]
  (variable_name) @usage.write)

(for_statement
  variable: (variable_name) @usage.write)

(command
  name: (command_name
    (word) @_read)
  argument: (word) @usage.write
  (#eq? @_read "read")
  (#not-lua-match? @usage.write "^-"))

(postfix_expression
  (variable_name) @usage.write)

; Read: $x, ${x}, ${x:-d}, ${a[@]}, $((x + 1)), [[ $x ]] (bashls ranges start at the name).
(variable_name) @usage.read
