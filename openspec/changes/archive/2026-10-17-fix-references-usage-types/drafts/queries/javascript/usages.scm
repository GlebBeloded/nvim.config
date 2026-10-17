; inherits: ecma

; ---- Usage in extends clause: `class A extends B`, `extends ns.B` ---------------
(class_heritage (identifier) @usage.extends)
(class_heritage (member_expression property: (property_identifier) @usage.extends))
