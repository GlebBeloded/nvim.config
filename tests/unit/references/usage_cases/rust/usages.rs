use crate::model::{Thing, store::Store as Repo};
use std::fmt;

#[derive(Debug, Clone)]
pub struct Holder<'a> {
    pub item: Thing,
    pub items: Vec<Option<model::Thing>>,
    pub borrowed: &'a Thing,
}

pub enum Event {
    Created(Thing),
    Moved { from: Thing, to: Box<dyn Shape + Send> },
}

pub struct Wrapper(pub Thing, std::sync::Arc<Thing>);

pub type Shared = std::sync::Arc<Thing>;
const DEFAULT: Thing = Thing::EMPTY;
static GLOBAL: Option<Thing> = None;

pub trait Shape: fmt::Debug + ?Sized {
    type Out: Into<Thing>;
    fn area(&self, scale: Thing) -> Thing;
}

impl Thing {
    pub fn new(name: &str, parent: &mut Thing, kids: Vec<Thing>) -> Option<Box<Thing>> {
        let local: Thing = Thing { name, size: 0, ..Thing::default() };
        let other = model::Thing { name: "x", size: local.size };
        local.resize(2);
        local.size = 3;
        let n = local.size;
        let y = n;
        helper();
        model::helper(&local);
        let v = Vec::<Thing>::new();
        let m = local.convert::<Thing>();
        let id = model::make::<Thing>();
        let w = Wrapper(other, v);
        println!("{} {}", local.name, n);
        model::log!(local);
        let s = n as Size;
        let cb = |t: Thing| -> Thing { t };
        None
    }
}

impl fmt::Display for model::Thing {}
impl<T: Shape> From<Thing> for Holder<T> where T: Clone + model::Shape {}

fn handle(e: Event, shape: impl Shape, dynamic: &dyn Shape, f: impl Fn(Thing) -> Thing) -> impl Shape {
    match e {
        Event::Created(t) => {}
        Event::Moved { from, to: Thing { size, .. } } => {}
        model::Kind::Empty => {}
    }
    if let Some(Thing { name, .. }) = maybe {}
}

fn negatives<'a>(mut acc: i32, xs: &'a [i32]) -> &'a str {
    acc = acc + 1;
    let total = acc;
    for x in xs { acc += *x; }
    total;
}

fn writes(mut c: Counter) {
    c.hits += 1;
    c.hits;
}
