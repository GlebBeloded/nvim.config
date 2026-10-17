; Usage type of an LSP reference position: the first pattern that captures a
; node starting at the reference wins. @usage.write / @usage.read last.
; A traversal `a.b.c` is (expression (variable_expr (identifier)) (get_attr (identifier))...);
; every segment is captured, so a range starting at the root or at a segment classifies.

; Dependency: every segment of a traversal listed in depends_on = [...].
(attribute
  (identifier) @_attribute
  (expression
    (collection_value
      (tuple
        (expression
          [
            (variable_expr
              (identifier) @usage.depends_on)
            (get_attr
              (identifier) @usage.depends_on)
          ]))))
  (#eq? @_attribute "depends_on"))

; Output: a module, resource, data or local traversal in an output block's value, directly or one
; level deep (template interpolation, tuple element, object value, function argument). An input
; variable (var.<name>) stays a read: the output reads it like any other expression.
(block
  (identifier) @_block
  (body
    (attribute
      (identifier) @_attribute
      [
        (expression
          (variable_expr
            (identifier) @_root @usage.output)
          (get_attr
            (identifier) @usage.output)*)
        (expression
          (template_expr
            (quoted_template
              (template_interpolation
                (expression
                  (variable_expr
                    (identifier) @_root @usage.output)
                  (get_attr
                    (identifier) @usage.output)*)))))
        (expression
          (collection_value
            (tuple
              (expression
                (variable_expr
                  (identifier) @_root @usage.output)
                (get_attr
                  (identifier) @usage.output)*))))
        (expression
          (collection_value
            (object
              (object_elem
                val: (expression
                  (variable_expr
                    (identifier) @_root @usage.output)
                  (get_attr
                    (identifier) @usage.output)*)))))
        (expression
          (function_call
            (function_arguments
              (expression
                (variable_expr
                  (identifier) @_root @usage.output)
                (get_attr
                  (identifier) @usage.output)*))))
      ]))
  (#eq? @_block "output")
  (#eq? @_attribute "value")
  (#not-eq? @_root "var"))

; Declarations: the block label, captured inside and including the quotes.
(block
  (identifier) @_block
  .
  (string_lit
    (template_literal) @usage.variable_declaration) @usage.variable_declaration
  (#eq? @_block "variable"))

(block
  (identifier) @_block
  .
  (string_lit
    (template_literal) @usage.module_declaration) @usage.module_declaration
  (#eq? @_block "module"))

(block
  (identifier) @_block
  .
  (string_lit
    (template_literal) @usage.output_declaration) @usage.output_declaration
  (#eq? @_block "output"))

(block
  (identifier) @_block
  .
  (string_lit)
  .
  (string_lit
    (template_literal) @usage.resource_declaration) @usage.resource_declaration
  (#eq? @_block "resource"))

(block
  (identifier) @_block
  .
  (string_lit)
  .
  (string_lit
    (template_literal) @usage.data_declaration) @usage.data_declaration
  (#eq? @_block "data"))

; Local value declaration: the key in locals { name = ... }.
(block
  (identifier) @_block
  (body
    (attribute
      (identifier) @usage.local_declaration))
  (#eq? @_block "locals"))

; Argument: a module input name in module "m" { region = ... }.
(block
  (identifier) @_block
  (body
    (attribute
      (identifier) @usage.attribute_assignment))
  (#eq? @_block "module")
  (#not-any-of? @usage.attribute_assignment
    "source" "version" "count" "for_each" "providers" "depends_on"))

; Module reference: module.<name>.<output>.
(expression
  (variable_expr
    (identifier) @_root @usage.module_reference)
  .
  (get_attr
    (identifier) @usage.module_reference)
  (#eq? @_root "module"))

(expression
  (variable_expr
    (identifier) @_root)
  .
  (get_attr)
  .
  (get_attr
    (identifier) @usage.module_reference)
  (#eq? @_root "module"))

; Data source reference: data.<type>.<name>.
(expression
  (variable_expr
    (identifier) @_root @usage.data_reference)
  .
  (get_attr
    (identifier) @usage.data_reference)
  (#eq? @_root "data"))

(expression
  (variable_expr
    (identifier) @_root)
  .
  (get_attr)
  .
  (get_attr
    (identifier) @usage.data_reference)
  (#eq? @_root "data"))

; Local value read: local.<name>.
(expression
  (variable_expr
    (identifier) @_root @usage.local_reference)
  .
  (get_attr
    (identifier) @usage.local_reference)
  (#eq? @_root "local"))

; Resource reference: <type>.<name> for any non-reserved root.
(expression
  (variable_expr
    (identifier) @_root @usage.resource_reference)
  .
  (get_attr
    (identifier) @usage.resource_reference)
  (#not-any-of? @_root
    "var" "local" "module" "data" "path" "terraform" "count" "each" "self"))

; Write (kind_ts parity): the label of variable "x".
(block
  (identifier) @_block
  (string_lit
    (template_literal) @usage.write)
  (#eq? @_block "variable"))

; Read (kind_ts parity): var.<name>; the root is captured for ranges starting at `var`.
(expression
  (variable_expr
    (identifier) @_root @usage.read)
  .
  (get_attr
    (identifier) @usage.read)
  (#eq? @_root "var"))

(identifier) @usage.read
