import Default, { Money, type Currency as Cur } from "./money";
import * as models from "./models";
export { Money as Cash } from "./money";

interface Priced extends Base<Money> {
  price: Money;
  convert(m: Money): Money;
}

class Wallet extends Base<Money> implements Priced, models.Serializable {
  static zero: Money = Money.ZERO;
  price: Money;
  private items: Money[] = [];

  constructor(private readonly initial: Money) {
    super();
    this.price = new Money(0);
  }

  convert(m: Money): Money {
    return Money.of(m.amount);
  }

  isMoney(x: unknown): x is Money {
    return x instanceof Money;
  }
}

function total(xs: Array<Money>, fx?: (m: Money) => Money): Money | undefined {
  const sum: Money = Money.sum(xs);
  let maybe = sum as Money;
  const old = <Money>sum;
  const checked = sum satisfies Money;
  const m2 = new models.Money(1);
  try {
    total([]);
  } catch (err: AppError) {
    console.error(err);
  }
  const fn = (a: Money): Money => a;
  sum.add(maybe);
  maybe = sum;
  return fn(sum);
}

const amount = total([]);
type Alias = Money;
const inst = Default.create<Money>();
const box = new Box<Money>(Money.ZERO);
function pick<U extends Money>(u: U, list: readonly (Money | Cur)[]): [Money, U] {
  return [u, u];
}
