use crate::a::{Thing, b::Other as O};
use std::fmt;
struct S { f: Thing, g: Vec<Thing> }
enum E { V(Thing), W { x: Thing } }
fn f(p: &Thing, q: &mut Thing, r: Vec<Thing>, s: Box<dyn Tr>, t: impl Tr) -> Thing where T: Tr + Tr2 {
    let x: Thing = Thing { a, b: 1, ..Default::default() };
    let y = a::Thing { a: 1 };
    foo(); a::foo(); x.meth(); x.field;
    match v { Thing::Variant(z) => {}, Thing { a, .. } => {}, a::Thing::U => {} }
    println!("{}", x);
    let c = x as Thing;
    let d = Vec::<Thing>::new();
}
impl Thing {}
impl Tr for Thing {}
impl<T: Tr> a::Tr for a::Thing<T> {}
type Al = Thing;
fn g<T: Tr>() {}
