from __future__ import annotations
import os.path as osp
import pkg.models
from pkg.models import Thing, Base as B
from .errors import AppError

type Alias = list[Thing] | None
Legacy: TypeAlias = dict[str, Thing]
counter: int = 0
x = 1
print(x)


class Repo(B, pkg.models.Mixin, Generic[Thing], metaclass=Meta):
    items: list[Thing] = field(default_factory=list)
    cache: dict[str, list[Optional[Thing]]] = {}

    @staticmethod
    @pkg.models.cached(ttl=10)
    def load(self, key: Thing, extra: Optional[Thing] = None, *rest: Thing, **kw: pkg.models.Thing) -> Thing | None:
        local: Thing = Thing(key)
        local.refresh()
        pkg.models.build(name=key)
        if isinstance(local, Thing) or issubclass(type(local), (Thing, pkg.models.Thing)):
            return local
        try:
            os.remove(key)
        except (AppError, pkg.models.Fail) as err:
            raise
        except AppError:
            pass
        y = x
        x2 = local
        return None

    def many(self) -> dict[str, list[Optional[Thing]]]:
        return {}


def handler(cb: Callable[[Thing], None], data: Annotated[Thing, Meta(strict=True)]) -> pkg.models.Thing:
    match data:
        case Thing(name="a"):
            pass
    return isinstance(data, Thing | None)


def negatives(a: int = DEFAULT, *, b=lambda q: q):
    total = 0
    total += a
    obj.attr = total
    del total
    return obj.attr, [v for v in a]


def factory():
    class Local:
        slot: Thing
    return Local


def writes(pairs):
    first, second = pairs
    for key, value in pairs:
        pass
    if (n := len(pairs)) > 1:
        obj.count += n
    return first, second, key, value
