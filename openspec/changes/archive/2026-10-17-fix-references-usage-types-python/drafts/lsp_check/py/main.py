from pkg.mod import Thing
import pkg.mod
import pkg.mod as m

a1 = m.Thing()
a2 = pkg.mod.Thing
obj = Thing()
obj.method()


@m.dec
def d1() -> None: ...


@m.deco2(1)
def d2() -> None: ...


class A(m.Base):
    pass


def chk(x: object) -> None:
    if isinstance(x, (m.Thing, int)):
        pass
    try:
        pass
    except m.Err:
        pass


def g(p: list[m.Thing]) -> m.Thing | None:
    return None


x: m.Thing = m.Thing()
m.f(name=1)
type Al = Thing
