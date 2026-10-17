package billing

import (
	"fmt"
	str "strings"
	"sort"
)

type Money struct {
	Amount   int64
	Currency string
	Next     *Money
	History  []Money
	ByCode   map[string]Money
	Other    str.Builder
	Hook     func(m Money) Money
	Items    List[Money]
}

type Number interface {
	~int | ~int64 | Money
}

type Converter interface {
	Convert(m Money) Money
	fmt.Stringer
}

type Embeds struct {
	Money
	*str.Reader
	Matrix map[string][]*Money
}

type List[T any] struct {
	items []T
}

type Alias = Money
type Wrapped Money
type PtrAlias = *Money

var zero Money
var ptr *Money = nil

const limit Money = Money{}

func (m *Money) Add(other Money) (Money, error) {
	return Money{Amount: m.Amount + other.Amount}, nil
}

func (m Money) Total() (result Money) {
	result = m
	return
}

func Sum[T Number](xs []T, mk func(Money) Money) T {
	var total T
	return total
}

func less(i, j int) bool { return i < j }

func Use(v any, xs []int, b str.Builder) {
	p := &Money{Currency: "EUR"}
	q := Money{}.Add(*p)
	r := str.Builder{}
	_ = r
	if mm, ok := v.(Money); ok {
		_ = mm
	}
	switch t := v.(type) {
	case Money, *Money:
		_ = t
	}
	c := Money(*p)
	d := (*Money)(p)
	e := []byte("x")
	l := List[Money]{}
	s := Sum[int]
	fmt.Println(q, c, d, e, l, s)
	sort.Slice(xs, less)
	_ = str.ToUpper("a")
	f := func(x Money) Money { return x }
	_ = f
	ms := []Money{{Amount: 1}}
	_ = ms
	keyed := map[string]int{fmt.Sprint(1): 1}
	_ = keyed
	p.Amount = 5
	amount := p.Amount
	_ = amount
	defer less(1, 2)
	go less(3, 4)
	_ = Sum[Money](nil, nil)
	_ = str.Builder(b)
	_ = List[List[Money]]{}
	var _ = (*Money)(nil)
}

func Make() func(x Money) Money { return nil }


type Pair[K comparable, V any] struct{ k K; v V }

func Variadic(ms ...Money) chan Money {
	_ = Pair[string, Money]{}
	return nil
}
