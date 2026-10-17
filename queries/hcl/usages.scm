; Usage type of an LSP reference position: the first pattern that captures a
; node starting at the reference wins. @usage.write / @usage.read last.

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
; level deep. An input variable stays a read.
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

; Local value declaration: the key in locals { name = ... }.
(block
  (identifier) @_block
  (body
    (attribute
      (identifier) @usage.variable_declaration))
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

; Write: the label of variable "x".
(block
  (identifier) @_block
  (string_lit
    (template_literal) @usage.write)
  (#eq? @_block "variable"))

; Read: var.<name>; the root is captured for ranges starting at `var`.
(expression
  (variable_expr
    (identifier) @_root @usage.read)
  .
  (get_attr
    (identifier) @usage.read)
  (#eq? @_root "var"))

(identifier) @usage.read
