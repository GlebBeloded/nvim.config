# Generates queries/typescript/usages.scm (tsx inherits it unchanged).
W = ("array_type generic_type union_type intersection_type parenthesized_type "
     "nested_type_identifier readonly_type tuple_type optional_type rest_type")

def tref(head, cap, close, depth=4):
    """Patterns capturing a type_identifier directly at `head` or nested in up to
    `depth` pure type wrappers (never through function/object types)."""
    c = f"@usage.{cap}"
    pats = [f"{head}(type_identifier) {c}{close}"]
    pred = lambda x: f"\n  (#has-parent? {x} {W})"
    if depth >= 1:
        pats.append(f"{head}(_ (type_identifier) {c}){close[:-1]}{pred(c)})")
    if depth >= 2:
        pats.append(f"{head}(_ (_ (type_identifier) {c}) @_w1){close[:-1]}{pred(c)}{pred('@_w1')})")
    if depth >= 3:
        pats.append(f"{head}(_ (_ (_ (type_identifier) {c}) @_w2) @_w1){close[:-1]}{pred(c)}{pred('@_w2')}{pred('@_w1')})")
    if depth >= 4:
        pats.append(f"{head}(_ (_ (_ (_ (type_identifier) {c}) @_w3) @_w2) @_w1){close[:-1]}{pred(c)}{pred('@_w3')}{pred('@_w2')}{pred('@_w1')})")
    return "\n".join(pats) + "\n"

def section(title):
    return f"\n; ---- {title} " + "-" * max(4, 74 - len(title)) + "\n"

ann = lambda owner: f"({owner} type: (type_annotation "
q = ["""; inherits: ecma,(ts_angle_cast)
; TypeScript type-position usage types; tsx inherits this file (`; inherits: typescript`).
; Precedence: first pattern capturing a node wins; inherited ecma (and
; ts_angle_cast for .ts) patterns come before these.
; Type references: a type_identifier directly in the context or nested up to 4
; levels in pure type wrappers (array/generic/union/intersection/parenthesized/
; qualified/readonly/tuple/optional/rest). They never cross function or object
; types, whose own parameters/properties are classified by their own patterns.
"""]
q.append(section("Usage in cast target type: `x as T`, `x satisfies T`"))
q.append(tref("(as_expression ", "cast", ")", 2))
q.append(tref("(satisfies_expression ", "cast", ")", 2))
q.append(section("Usage in instanceof: type predicate `x is T`"))
q.append(tref("(type_predicate type: ", "instanceof", ")", 2))
q.append(section("Type argument: `Array<T>`, `f<T>()`, `new C<T>()`, constraint `<U extends T>`"))
q.append(tref("(type_arguments ", "type_argument", ")", 3))
q.append(tref("(constraint ", "type_argument", ")", 2))
q.append(section("Usage in extends/implements clause"))
q.append("""(extends_clause value: (identifier) @usage.extends)
(extends_clause value: (member_expression property: (property_identifier) @usage.extends))
""")
q.append(tref("(extends_type_clause type: ", "extends", ")", 1))
q.append(tref("(implements_clause ", "extends", ")", 1))
q.append(section("Type alias: `type A = T`, `type A = T[] | U`"))
q.append(tref("(type_alias_declaration value: ", "type_alias", ")"))
q.append(section("Field declaration: class field, interface/object type property"))
q.append(tref(ann("public_field_definition"), "field_declaration", "))"))
q.append(tref(ann("property_signature"), "field_declaration", "))"))
q.append(section("Local variable declaration: `const x: T`"))
q.append(tref(ann("variable_declarator"), "local_declaration", "))"))
q.append(section("Method parameter declaration"))
q.append(tref(ann("required_parameter"), "parameter_declaration", "))"))
q.append(tref(ann("optional_parameter"), "parameter_declaration", "))"))
q.append(section("Catch clause parameter declaration: `catch (e: T)`"))
q.append(tref(ann("catch_clause"), "catch_declaration", "))"))
q.append(section("Method return type (functions, methods, arrows, signatures, function types)"))
q.append(tref("(_ return_type: (type_annotation ", "return_type", "))"))
q.append(tref("(function_type return_type: ", "return_type", ")"))
open("queries/typescript/usages.scm", "w").write("".join(q))
