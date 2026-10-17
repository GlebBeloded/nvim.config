import Money, { Currency, convert as conv } from "./money.js";
import * as utils from "./utils.js";
export { Money as Cash } from "./money.js";

class Wallet extends Money {
  static create() {
    return new Wallet(Money.ZERO);
  }
}

class Purse extends utils.Container {}

function run(input) {
  const m = new Money(5);
  const n = new utils.Money(5);
  if (input instanceof Money) {
    conv(input, Currency.EUR);
  }
  try {
    utils.process(m);
  } catch (err) {
    console.error(err);
  }
  let total = m;
  total = n;
  return Money.sum(total, utils.value);
}
