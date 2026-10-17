; JS/TS shared usage types (ids of JetBrains JSUsageTypeProvider). Base of
; javascript, typescript and tsx (via `; inherits: ecma`): only nodes common to all
; three grammars. Inherited files are concatenated first, so these patterns win
; over the inheriting file's patterns when both capture the same node.
; Contract: every capture is the node whose start equals the LSP reference start;
; the first pattern (lowest index) capturing a node wins.

; ---- Usage in import ---------------------------------------------------------
(import_specifier name: (identifier) @usage.import)
(import_specifier alias: (identifier) @usage.import)
(import_clause (identifier) @usage.import)
(namespace_import (identifier) @usage.import)
; re-export `export { T as U } from "m"` (child patterns are ordered: clause before source)
(export_statement
  (export_clause (export_specifier name: (identifier) @usage.import))
  source: (_))

; ---- New instance creation: `new T()`, `new ns.T()` ---------------------------
(new_expression constructor: (identifier) @usage.new)
(new_expression
  constructor: (member_expression property: (property_identifier) @usage.new))

; ---- Usage in instanceof: `x instanceof T` -------------------------------------
(binary_expression operator: "instanceof" right: (identifier) @usage.instanceof)
(binary_expression
  operator: "instanceof"
  right: (member_expression property: (property_identifier) @usage.instanceof))

; ---- Usage in function call: `f()`, `obj.f()`, `obj?.f()`, `obj.#f()` -----------
(call_expression function: (identifier) @usage.call)
(call_expression
  function: (member_expression
    property: [(property_identifier) (private_property_identifier)] @usage.call))

; ---- Class static member access: `T.staticThing` --------------------------------
; Syntax cannot tell a class from a variable: PascalCase heuristic here, and the
; caller keeps it only when the referenced symbol is a class/type.
((member_expression object: (identifier) @usage.static_member)
  (#lua-match? @usage.static_member "^[A-Z]"))
