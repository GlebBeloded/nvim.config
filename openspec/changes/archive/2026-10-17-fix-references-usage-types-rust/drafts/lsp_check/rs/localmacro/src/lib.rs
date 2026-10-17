pub mod a {
    pub struct Thing {
        pub field: i32,
    }
    impl Thing {
        pub fn method(&self) {}
        pub fn new() -> Self {
            Thing { field: 0 }
        }
    }
    pub fn foo() {}
    pub trait Tr {}
    pub enum En {
        V(i32),
        W { x: i32 },
    }
    pub type Num = i32;
    #[macro_export]
    macro_rules! mm {
        () => {};
    }
}

use crate::a::{Thing, foo};
use crate::a::Tr as T2;

impl a::Tr for a::Thing {}

pub fn h(t: &a::Thing) -> Vec<a::Thing> {
    let _s = crate::a::Thing { field: 1 };
    a::foo();
    foo();
    t.method();
    let _v = t.field;
    let _n = Thing::new();
    let _q = a::Thing::new();
    let _ = t.field;
    let thing_var = 3;
    println!("{}", thing_var);
    format!("{thing_var}");
    let field = 5;
    let _w = Thing { field };
    let _c = thing_var as a::Num;
    mm!();
    vec_id!(Thing::new())
}

pub fn m(e: a::En) -> i32 {
    match e {
        a::En::V(z) => z,
        a::En::W { x } => x,
    }
}

pub fn uses_t2<T: T2>(_t: T) {}
#[macro_export]
macro_rules! vec_id { ($e:expr) => { ::std::vec![$e] }; }
