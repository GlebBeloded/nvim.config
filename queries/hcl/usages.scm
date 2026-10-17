(block
  (identifier) @_block_type
  (string_lit (template_literal) @usage.write)
  (#eq? @_block_type "variable"))
(expression
  (variable_expr (identifier) @_root)
  (get_attr (identifier) @usage.read)
  (#eq? @_root "var"))
