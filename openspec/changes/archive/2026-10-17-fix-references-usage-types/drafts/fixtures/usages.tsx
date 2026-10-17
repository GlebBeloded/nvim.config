import { Money } from "./money";
import React from "react";

type Props = { value: Money; onChange?: (next: Money) => void };

export function Price({ value }: Props): JSX.Element {
  const parsed: Money = Money.parse(String(value));
  const casted = value as unknown as Money;
  if (parsed instanceof Money) {
    console.log(new Money(1));
  }
  const list: ReadonlyArray<Money> = [];
  try {
    format(parsed);
  } catch (e: unknown) {
    return <span>{String(e)}</span>;
  }
  return <span>{casted.toString()}</span>;
}

function format(m: Money): string {
  return m.toString();
}
