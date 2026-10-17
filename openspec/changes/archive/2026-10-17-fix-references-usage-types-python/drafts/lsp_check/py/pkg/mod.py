class Thing:
    def method(self) -> int:
        return 1


def f(name: int = 0) -> int:
    return name


class Base:
    pass


def dec(fn):
    return fn


def deco2(x):
    def inner(fn):
        return fn
    return inner


class Err(Exception):
    pass
