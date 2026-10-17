; Usage-type classification for LSP reference positions (Rust).
; Each capture @usage.<id> names a usage type catalogue id and marks the identifier node whose start is the
; reference start (rust-analyzer points at the last path segment). When several
; patterns capture the same node, the pattern that comes FIRST in this file wins.
; Path qualifiers (`a`, `b`, `Thing` in `a::b::Thing::new()`) take the label of
; the whole path, like intellij-rust (it walks up RsPath before deciding):
; they are always modules/types/traits/enums, never values. Qualifier
; alternations cover up to four segments.
; Underscore captures (@_x) are helpers and never a result.

; import: every segment of a `use` tree, incl. `as` aliases
((identifier) @usage.import
  (#has-ancestor? @usage.import use_declaration))

; macro: m!(), a::m!()
(macro_invocation
  macro: [(identifier) @usage.macro
          (scoped_identifier name: (identifier) @usage.macro)
          (scoped_identifier
            path: [(identifier) @usage.macro
                   (scoped_identifier (identifier) @usage.macro)
                   (scoped_identifier (scoped_identifier (identifier) @usage.macro))])])

; macro_argument: any identifier inside a macro call's token tree
; (token trees are flat: `x.f()` inside println! is just identifiers)
((identifier) @usage.macro_argument
  (#has-ancestor? @usage.macro_argument token_tree)
  (#has-ancestor? @usage.macro_argument macro_invocation))

; type_constraint: `T: Tr`, `where T: Tr`, `impl Tr`, `dyn Tr`, `dyn A + B`,
; `?Sized`, supertraits, `Fn(A) -> B` sugar, `for<'a> Fn(..)`
((type_identifier) @usage.type_constraint
  (#has-parent? @usage.type_constraint
    trait_bounds removed_trait_bound bounded_type dynamic_type abstract_type higher_ranked_trait_bound))
((scoped_type_identifier
   name: (type_identifier) @usage.type_constraint) @_s
  (#has-parent? @_s
    trait_bounds removed_trait_bound bounded_type dynamic_type abstract_type higher_ranked_trait_bound))
((scoped_type_identifier
   path: [(identifier) @usage.type_constraint
          (scoped_identifier (identifier) @usage.type_constraint)
          (scoped_identifier (scoped_identifier (identifier) @usage.type_constraint))]) @_s
  (#has-parent? @_s
    trait_bounds removed_trait_bound bounded_type dynamic_type abstract_type higher_ranked_trait_bound))
((generic_type
   type: [(type_identifier) @usage.type_constraint
          (scoped_type_identifier name: (type_identifier) @usage.type_constraint)
          (scoped_type_identifier
            path: [(identifier) @usage.type_constraint
                   (scoped_identifier (identifier) @usage.type_constraint)])]) @_g
  (#has-parent? @_g
    trait_bounds removed_trait_bound bounded_type dynamic_type abstract_type higher_ranked_trait_bound))
(function_type
  trait: [(type_identifier) @usage.type_constraint
          (scoped_type_identifier name: (type_identifier) @usage.type_constraint)
          (scoped_type_identifier
            path: [(identifier) @usage.type_constraint
                   (scoped_identifier (identifier) @usage.type_constraint)])])

; struct_initialization: T { .. }, a::T { .. }, E::V { .. }, T::<U> { .. }
(struct_expression
  name: [(type_identifier) @usage.struct_initialization
         (scoped_type_identifier name: (type_identifier) @usage.struct_initialization)
         (scoped_type_identifier
           path: [(identifier) @usage.struct_initialization
                  (scoped_identifier (identifier) @usage.struct_initialization)
                  (scoped_identifier (scoped_identifier (identifier) @usage.struct_initialization))])
         (generic_type_with_turbofish
           type: [(type_identifier) @usage.struct_initialization
                  (scoped_identifier (identifier) @usage.struct_initialization)
                  (scoped_identifier (scoped_identifier (identifier) @usage.struct_initialization))])])

; field_initialization: T { a: 1 } and shorthand T { a }
; (shorthand is also a read of the local `a`; both references land here)
(field_initializer field: (field_identifier) @usage.field_initialization)
(shorthand_field_initializer (identifier) @usage.field_initialization)

; pattern: T::V(x), a::T { f, .. }, a::E::Unit, field names in struct patterns
(tuple_struct_pattern
  type: [(identifier) @usage.pattern
         (scoped_identifier name: (identifier) @usage.pattern)
         (scoped_identifier
           path: [(identifier) @usage.pattern
                  (scoped_identifier (identifier) @usage.pattern)
                  (scoped_identifier (scoped_identifier (identifier) @usage.pattern))])])
(struct_pattern
  type: [(type_identifier) @usage.pattern
         (scoped_type_identifier name: (type_identifier) @usage.pattern)
         (scoped_type_identifier
           path: [(identifier) @usage.pattern
                  (scoped_identifier (identifier) @usage.pattern)
                  (scoped_identifier (scoped_identifier (identifier) @usage.pattern))])])
(field_pattern name: [(field_identifier) (shorthand_field_identifier)] @usage.pattern)
((scoped_identifier
   [name: (identifier) @usage.pattern
    path: [(identifier) @usage.pattern
           (scoped_identifier (identifier) @usage.pattern)
           (scoped_identifier (scoped_identifier (identifier) @usage.pattern))]]) @_p
  (#has-parent? @_p
    match_pattern or_pattern tuple_pattern tuple_struct_pattern slice_pattern
    field_pattern reference_pattern ref_pattern let_condition))
(let_declaration
  pattern: (scoped_identifier
    [name: (identifier) @usage.pattern
     path: [(identifier) @usage.pattern
            (scoped_identifier (identifier) @usage.pattern)]]))

; call (method): x.m(), x.m::<T>()
(call_expression
  function: [(field_expression field: (field_identifier) @usage.call)
             (generic_function
               function: (field_expression field: (field_identifier) @usage.call))])

; call: f(), a::f(), T::new(), Vec::<T>::new(), f::<T>(), tuple-struct/variant ctors
(call_expression
  function: [(identifier) @usage.call
             (scoped_identifier name: (identifier) @usage.call)
             (generic_function
               function: [(identifier) @usage.call
                          (scoped_identifier name: (identifier) @usage.call)])])
(call_expression
  function: [(scoped_identifier
              path: [(identifier) @usage.call
                     (scoped_identifier (identifier) @usage.call)
                     (scoped_identifier (scoped_identifier (identifier) @usage.call))
                     (generic_type type: (type_identifier) @usage.call)])
             (generic_function
               function: (scoped_identifier
                 path: [(identifier) @usage.call
                        (scoped_identifier (identifier) @usage.call)
                        (scoped_identifier (scoped_identifier (identifier) @usage.call))]))])

; write: the field of an assignment target, `x.f = v` and `x.f += v`; it reaches
; Value write through documentHighlight or this fallback
(assignment_expression
  left: (field_expression field: (field_identifier) @usage.write))
(compound_assignment_expr
  left: (field_expression field: (field_identifier) @usage.write))

; field_access: every other x.field
(field_expression field: (field_identifier) @usage.field_access)

; field_declaration: anything in a struct / enum-variant field type
([(type_identifier) (primitive_type)] @usage.field_declaration
  (#has-ancestor? @usage.field_declaration field_declaration ordered_field_declaration_list))
((identifier) @usage.field_declaration
  (#has-ancestor? @usage.field_declaration field_declaration ordered_field_declaration_list)
  (#has-ancestor? @usage.field_declaration scoped_type_identifier))

; parameter_declaration: anything in a parameter type (fn, closure, trait fn)
([(type_identifier) (primitive_type)] @usage.parameter_declaration
  (#has-ancestor? @usage.parameter_declaration parameter))
((identifier) @usage.parameter_declaration
  (#has-ancestor? @usage.parameter_declaration parameter)
  (#has-ancestor? @usage.parameter_declaration scoped_type_identifier))

; return_type: `-> T` of fn items, trait fn signatures, closures
(function_item
  return_type: [[(type_identifier) (primitive_type)] @usage.return_type
                (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)
                (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))
                (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))
                (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))
                (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))
                (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))
                (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))))
                (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))))]
  (#not-has-parent? @usage.return_type lifetime))
(function_signature_item
  return_type: [[(type_identifier) (primitive_type)] @usage.return_type
                (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)
                (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))
                (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))
                (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))
                (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))
                (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))
                (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))))
                (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))))]
  (#not-has-parent? @usage.return_type lifetime))
(closure_expression
  return_type: [[(type_identifier) (primitive_type)] @usage.return_type
                (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)
                (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))
                (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))
                (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))
                (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))
                (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))
                (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type)))))))
                (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.return_type))))))))]
  (#not-has-parent? @usage.return_type lifetime))

; variable_declaration: `let x: T`, `const C: T`, `static S: T`
(let_declaration
  type: [[(type_identifier) (primitive_type)] @usage.variable_declaration
         (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)
         (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))
         (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))
         (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))
         (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))
         (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))
         (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))))
         (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))))]
  (#not-has-parent? @usage.variable_declaration lifetime))
(const_item
  type: [[(type_identifier) (primitive_type)] @usage.variable_declaration
         (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)
         (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))
         (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))
         (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))
         (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))
         (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))
         (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))))
         (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))))]
  (#not-has-parent? @usage.variable_declaration lifetime))
(static_item
  type: [[(type_identifier) (primitive_type)] @usage.variable_declaration
         (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)
         (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))
         (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))
         (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))
         (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))
         (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))
         (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration)))))))
         (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.variable_declaration))))))))]
  (#not-has-parent? @usage.variable_declaration lifetime))

; type_alias: `type A = T;` (right side only)
(type_item
  type: [[(type_identifier) (primitive_type)] @usage.type_alias
         (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias)
         (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias))
         (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias)))
         (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias))))
         (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias)))))
         (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias))))))
         (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias)))))))
         (_ (_ (_ (_ (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.type_alias))))))))]
  (#not-has-parent? @usage.type_alias lifetime))

; cast: `x as T`
(type_cast_expression
  type: [[(type_identifier) (primitive_type)] @usage.cast
         (_ [(type_identifier) (primitive_type) (identifier)] @usage.cast)
         (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.cast))
         (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.cast)))
         (_ (_ (_ (_ [(type_identifier) (primitive_type) (identifier)] @usage.cast))))]
  (#not-has-parent? @usage.cast lifetime))

; impl: self type head of `impl T` / `impl Tr for T` (generic args -> type_instantiation)
(impl_item
  type: [(type_identifier) @usage.impl
         (scoped_type_identifier name: (type_identifier) @usage.impl)
         (scoped_type_identifier
           path: [(identifier) @usage.impl
                  (scoped_identifier (identifier) @usage.impl)
                  (scoped_identifier (scoped_identifier (identifier) @usage.impl))])
         (generic_type
           type: [(type_identifier) @usage.impl
                  (scoped_type_identifier name: (type_identifier) @usage.impl)
                  (scoped_type_identifier
                    path: [(identifier) @usage.impl
                           (scoped_identifier (identifier) @usage.impl)
                           (scoped_identifier (scoped_identifier (identifier) @usage.impl))])])])

; extends: trait head of `impl Tr for T` (Supertype)
(impl_item
  trait: [(type_identifier) @usage.extends
          (scoped_type_identifier name: (type_identifier) @usage.extends)
          (scoped_type_identifier
            path: [(identifier) @usage.extends
                   (scoped_identifier (identifier) @usage.extends)
                   (scoped_identifier (scoped_identifier (identifier) @usage.extends))])
          (generic_type
            type: [(type_identifier) @usage.extends
                   (scoped_type_identifier name: (type_identifier) @usage.extends)
                   (scoped_type_identifier
                     path: [(identifier) @usage.extends
                            (scoped_identifier (identifier) @usage.extends)
                            (scoped_identifier (scoped_identifier (identifier) @usage.extends))])])])

; type_instantiation: generic args / Fn-sugar args / assoc-type bindings not covered above
([(type_identifier) (primitive_type)] @usage.type_instantiation
  (#has-ancestor? @usage.type_instantiation type_arguments function_type))
((identifier) @usage.type_instantiation
  (#has-ancestor? @usage.type_instantiation type_arguments function_type)
  (#has-ancestor? @usage.type_instantiation scoped_type_identifier))
