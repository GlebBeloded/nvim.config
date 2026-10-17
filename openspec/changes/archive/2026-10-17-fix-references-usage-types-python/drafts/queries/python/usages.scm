; Usage-type classification for LSP reference positions (Python).
; Each capture @usage.<type_id> marks the identifier node whose start is the
; reference start. When several patterns capture the same node, the pattern
; that comes FIRST in this file wins, so order = precedence.
; Tree-sitter has no "descendant at any depth" operator: unbounded nesting is
; expressed with #has-ancestor?, bounded nesting with a depth-enumerated
; alternation of wildcards (depth 0..9 under the annotation's `type` node,
; i.e. three levels of generics such as dict[str, list[Optional[T]]]).

; import: every segment and alias in import statements
((identifier) @usage.import
  (#has-ancestor? @usage.import import_statement import_from_statement future_import_statement))

; decorator: @name, @mod.name, @name(...), @mod.name(...)
(decorator (identifier) @usage.decorator)
(decorator (attribute attribute: (identifier) @usage.decorator))
(decorator (call function: (identifier) @usage.decorator))
(decorator (call function: (attribute attribute: (identifier) @usage.decorator)))

; extends (Supertype): class A(Base, mod.Base, Generic[T], metaclass=M)
(class_definition
  superclasses: (argument_list
    [(identifier) @usage.extends
     (attribute attribute: (identifier) @usage.extends)
     (subscript value: (identifier) @usage.extends)
     (subscript value: (attribute attribute: (identifier) @usage.extends))
     (subscript subscript: (identifier) @usage.extends)
     (subscript subscript: (attribute attribute: (identifier) @usage.extends))
     (keyword_argument value: (identifier) @usage.extends)
     (keyword_argument value: (attribute attribute: (identifier) @usage.extends))]))

; instanceof (Type check): 2nd argument of isinstance/issubclass, incl. tuples and A | B
(call
  function: (identifier) @_fn
  arguments: (argument_list . (_) .
    [(identifier) @usage.instanceof
     (attribute attribute: (identifier) @usage.instanceof)
     (tuple (identifier) @usage.instanceof)
     (tuple (attribute attribute: (identifier) @usage.instanceof))
     (binary_operator (identifier) @usage.instanceof)
     (binary_operator (attribute attribute: (identifier) @usage.instanceof))
     (binary_operator (binary_operator (identifier) @usage.instanceof))])
  (#any-of? @_fn "isinstance" "issubclass"))

; catch (Catch clause): except T / except (A, mod.B) as e / except* T
(except_clause
  value: [(identifier) @usage.catch
          (attribute attribute: (identifier) @usage.catch)
          (tuple (identifier) @usage.catch)
          (tuple (attribute attribute: (identifier) @usage.catch))
          (as_pattern (identifier) @usage.catch)
          (as_pattern (attribute attribute: (identifier) @usage.catch))
          (as_pattern (tuple (identifier) @usage.catch))
          (as_pattern (tuple (attribute attribute: (identifier) @usage.catch)))])

; keyword_argument: f(name=...) as a usage of the parameter `name`
(call arguments: (argument_list (keyword_argument name: (identifier) @usage.keyword_argument)))

; call: f(), obj.m(), mod.f()  (the qualifier is a value read, not captured)
(call function: (identifier) @usage.call)
(call function: (attribute attribute: (identifier) @usage.call))

; pattern (extra): case Point(x=0) / case mod.Point()
(class_pattern (dotted_name (identifier) @usage.pattern .))
(keyword_pattern . (identifier) @usage.pattern)

; parameter_declaration: any identifier inside a parameter annotation
((identifier) @usage.parameter_declaration
  (#has-ancestor? @usage.parameter_declaration type)
  (#has-ancestor? @usage.parameter_declaration typed_parameter typed_default_parameter))

; field_declaration: annotated assignment directly in a class body
(class_definition
  body: (block
    (expression_statement
      (assignment
        type: (type
          [(identifier) @usage.field_declaration
           (_ (identifier) @usage.field_declaration)
           (_ (_ (identifier) @usage.field_declaration))
           (_ (_ (_ (identifier) @usage.field_declaration)))
           (_ (_ (_ (_ (identifier) @usage.field_declaration))))
           (_ (_ (_ (_ (_ (identifier) @usage.field_declaration)))))
           (_ (_ (_ (_ (_ (_ (identifier) @usage.field_declaration))))))
           (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.field_declaration)))))))
           (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.field_declaration))))))))
           (_ (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.field_declaration)))))))))])))))

; variable_declaration: any other annotated assignment `x: T = ...`
((identifier) @usage.variable_declaration
  (#has-ancestor? @usage.variable_declaration type)
  (#has-ancestor? @usage.variable_declaration assignment))

; type_alias: `type A = T` (right side) and `A: TypeAlias = T`
(type_alias_statement
  right: (type
    [(identifier) @usage.type_alias
     (_ (identifier) @usage.type_alias)
     (_ (_ (identifier) @usage.type_alias))
     (_ (_ (_ (identifier) @usage.type_alias)))
     (_ (_ (_ (_ (identifier) @usage.type_alias))))
     (_ (_ (_ (_ (_ (identifier) @usage.type_alias)))))
     (_ (_ (_ (_ (_ (_ (identifier) @usage.type_alias))))))
     (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.type_alias)))))))
     (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.type_alias))))))))
     (_ (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.type_alias)))))))))]))
(assignment
  type: (type [(identifier) @_ta (attribute attribute: (identifier) @_ta)])
  right: [(identifier) @usage.type_alias
          (_ (identifier) @usage.type_alias)
          (_ (_ (identifier) @usage.type_alias))
          (_ (_ (_ (identifier) @usage.type_alias)))
          (_ (_ (_ (_ (identifier) @usage.type_alias))))
          (_ (_ (_ (_ (_ (identifier) @usage.type_alias)))))
          (_ (_ (_ (_ (_ (_ (identifier) @usage.type_alias))))))]
  (#eq? @_ta "TypeAlias"))

; return_type: `-> T`, incl. generics, unions, qualified names
(function_definition
  return_type: (type
    [(identifier) @usage.return_type
     (_ (identifier) @usage.return_type)
     (_ (_ (identifier) @usage.return_type))
     (_ (_ (_ (identifier) @usage.return_type)))
     (_ (_ (_ (_ (identifier) @usage.return_type))))
     (_ (_ (_ (_ (_ (identifier) @usage.return_type)))))
     (_ (_ (_ (_ (_ (_ (identifier) @usage.return_type))))))
     (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.return_type)))))))
     (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.return_type))))))))
     (_ (_ (_ (_ (_ (_ (_ (_ (_ (identifier) @usage.return_type)))))))))]))

; write: assignment targets, used only when the server gives no write/read (classification step 3)
(assignment left: (identifier) @usage.write)
(assignment left: (attribute attribute: (identifier) @usage.write))
(assignment left: [(pattern_list (identifier) @usage.write) (tuple_pattern (identifier) @usage.write) (list_pattern (identifier) @usage.write)])
(augmented_assignment left: (identifier) @usage.write)
(augmented_assignment left: (attribute attribute: (identifier) @usage.write))
(for_statement left: (identifier) @usage.write)
(for_statement left: [(pattern_list (identifier) @usage.write) (tuple_pattern (identifier) @usage.write)])
(named_expression name: (identifier) @usage.write)
