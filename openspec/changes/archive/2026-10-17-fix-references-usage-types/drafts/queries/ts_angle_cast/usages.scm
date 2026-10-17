; Pseudo-language holding the `<T>x` cast, which the tsx grammar does not have.
; typescript/usages.scm includes it as an optional base `(ts_angle_cast)`;
; core skips optional bases when typescript is itself inherited (by tsx).
(type_assertion (type_arguments (type_identifier) @usage.cast))
(type_assertion
  (type_arguments (nested_type_identifier name: (type_identifier) @usage.cast)))
