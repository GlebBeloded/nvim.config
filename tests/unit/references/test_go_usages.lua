local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

local GO_SOURCE = [=[package billing

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
]=]

-- Raw query expectations. Ambiguous entries are refined through the real
-- classifier in the target-kind scenarios below.
local GO_CASES = {
	{ 4, '"fmt"', "import" },
	{ 5, "str", "import" },
	{ 12, "Money", "field_declaration" },
	{ 13, "Money", "field_declaration" },
	{ 14, "string", "field_declaration" },
	{ 14, "Money", "field_declaration" },
	{ 15, "Builder", "field_declaration" },
	{ 16, "Money", "parameter_declaration", nth = 1 },
	{ 16, "Money", "return_type", nth = 2 },
	{ 17, "List", "field_declaration" },
	{ 17, "Money", "type_instantiation" },
	{ 21, "Money", "type_constraint" },
	{ 21, "int64", "type_constraint" },
	{ 25, "Money", "parameter_declaration", nth = 1 },
	{ 25, "Money", "return_type", nth = 2 },
	{ 26, "Stringer", "type_constraint" },
	{ 30, "Money", "field_declaration" },
	{ 31, "Reader", "field_declaration" },
	{ 32, "Money", "field_declaration" },
	{ 36, "T", "field_declaration" },
	{ 39, "Money", "type_alias" },
	{ 40, "Money", "type_alias" },
	{ 41, "Money", "type_alias" },
	{ 43, "Money", "variable_declaration" },
	{ 44, "Money", "variable_declaration" },
	{ 46, "Money", "const_declaration", nth = 1 },
	{ 46, "Money", "struct_initialization", nth = 2 },
	{ 48, "Money", "receiver", nth = 1 },
	{ 48, "Money", "parameter_declaration", nth = 2 },
	{ 48, "Money", "return_type", nth = 3 },
	{ 48, "error", "return_type" },
	{ 49, "Money", "struct_initialization" },
	{ 49, "Amount", "write", nth = 1 },
	{ 49, "Amount", "read", nth = 2 },
	{ 52, "Money", "receiver", nth = 1 },
	{ 52, "Money", "return_type", nth = 2 },
	{ 57, "Number", "type_parameter_declaration" },
	{ 57, "[]T", "parameter_declaration", off = 2 },
	{ 57, "Money", "parameter_declaration", nth = 1 },
	{ 57, "Money", "return_type", nth = 2 },
	{ 57, ") T", "return_type", off = 2 },
	{ 58, "T", "variable_declaration" },
	{ 64, "Builder", "parameter_declaration" },
	{ 65, "Money", "struct_initialization" },
	{ 65, "Currency", "write" },
	{ 66, "Money", "struct_initialization" },
	{ 66, "Add", "call" },
	{ 67, "Builder", "struct_initialization" },
	{ 69, "Money", "type_assertion" },
	{ 73, "Money", "type_assertion", nth = 1 },
	{ 73, "Money", "type_assertion", nth = 2 },
	{ 76, "Money", "call" },
	{ 77, "Money", "type_conversion" },
	{ 78, "byte", "type_conversion" },
	{ 79, "List", "struct_initialization" },
	{ 79, "Money", "type_instantiation" },
	{ 81, "Println", "call" },
	{ 82, "Slice", "call" },
	{ 82, "less", "function_argument" },
	{ 83, "ToUpper", "call" },
	{ 84, "Money", "parameter_declaration", nth = 1 },
	{ 84, "Money", "return_type", nth = 2 },
	{ 86, "Amount", "write" },
	{ 93, "less", "call" },
	{ 94, "less", "call" },
	{ 95, "Sum", "call" },
	{ 95, "Money", "type_instantiation" },
	{ 96, "Builder", "call" },
	{ 97, "List", "struct_initialization", nth = 1 },
	{ 97, "List", "type_instantiation", nth = 2 },
	{ 97, "Money", "type_instantiation" },
	{ 98, "Money", "type_conversion" },
	{ 101, "Money", "parameter_declaration", nth = 1 },
	{ 101, "Money", "return_type", nth = 2 },
	{ 53, "result", "read" },
	{ 53, "m", "read", nth = 1 },
	{ 59, "total", "read" },
	{ 62, "i", "read", nth = 3 },
	{ 68, "r", "read" },
	{ 69, "v", "read" },
	{ 81, "q", "function_argument" },
	{ 81, "fmt", "read" },
	{ 82, "xs", "function_argument" },
	{ 86, "Money", "read" },
	{ 88, "Sprint", "call" },
	{ 90, "p", "read" },
	{ 90, "Amount", "read" },
	{ 91, "Amount", "read" },
	{ 91, "amount", "read" },
	{ 104, "comparable", "type_parameter_declaration" },
	{ 104, "K;", "field_declaration" },
	{ 106, "Money", "parameter_declaration", nth = 1 },
	{ 106, "Money", "return_type", nth = 2 },
	{ 107, "Pair", "struct_initialization" },
	{ 107, "string", "type_instantiation" },
	{ 107, "Money", "type_instantiation" },
}

local function find_column(line, needle, nth)
	local from = 1
	for _ = 1, nth or 1 do
		local start = assert(line:find(needle, from, true), needle)
		from = start + 1
		if _ == (nth or 1) then
			return start - 1
		end
	end
end

T["references: Go query classifies every GoLand usage type"] = function()
	local lines = vim.split(GO_SOURCE, "\n", { plain = true })
	local positions, expected = {}, {}
	for _, case in ipairs(GO_CASES) do
		positions[#positions + 1] = {
			line = case[1] - 1,
			character = find_column(lines[case[1]], case[2], case.nth) + (case.off or 0),
		}
		expected[#expected + 1] = case[3]
	end

	local actual = child.lua_get([[require("gleb.references.kind_ts").classify(...)]], { GO_SOURCE, "go", positions })
	eq(actual, expected)
end

local function classify_with_target(opts)
	local path = child.fn.tempname() .. "." .. opts.extension
	child.fn.writefile(vim.split(opts.source, "\n", { plain = true }), path)
	child.lua(
		[=[
		local opts, path = ...
		local uri = vim.uri_from_fname(path)
		local target = { line = opts.target_line, character = opts.target_character }
		local usage = { line = opts.usage_line, character = opts.usage_character }
		local client = {
			id = 991,
			name = "target-kind-test",
			offset_encoding = "utf-8",
			server_capabilities = {},
		}
		function client:supports_method(method)
			return method == "textDocument/definition"
				or method == "textDocument/documentSymbol"
				or (opts.highlight and method == "textDocument/documentHighlight")
		end
		function client:request(method, _, callback)
			vim.schedule(function()
				if method == "textDocument/definition" then
					callback(nil, { uri = uri, range = { start = target, ["end"] = target } })
				elseif method == "textDocument/documentSymbol" then
					callback(nil, { {
						name = "target",
						kind = opts.symbol_kind,
						range = { start = target, ["end"] = target },
						selectionRange = { start = target, ["end"] = target },
					} })
				else
					callback(nil, { {
						kind = 3,
						range = { start = usage, ["end"] = usage },
					} })
				end
			end)
			return true
		end
		vim.lsp.get_client_by_id = function(id)
			return id == client.id and client or nil
		end
		vim.lsp.get_clients = function()
			return { client }
		end
		_G.target_kind_result = nil
		require("gleb.references.kind").classify({ {
			uri = uri,
			path = path,
			lnum = usage.line + 1,
			col = usage.character + 1,
			filetype = opts.filetype,
			range = { start = usage, ["end"] = usage },
			client_id = client.id,
		} }, function(usages)
			_G.target_kind_result = usages[1].kind
		end, {
			client_id = client.id,
			params = { textDocument = { uri = uri }, position = usage },
			cwd = vim.fs.dirname(path),
		})
	]=],
		{ opts, path }
	)
	eq(child.wait("_G.target_kind_result ~= nil", 1000), true)
	return child.lua_get("_G.target_kind_result")
end

T["references: A Go conversion of a type is a type conversion"] = function()
	eq(
		classify_with_target({
			source = "package p\ntype Money int\nfunc f(x int) { _ = Money(x) }",
			extension = "go",
			filetype = "go",
			target_line = 1,
			target_character = 5,
			usage_line = 2,
			usage_character = 20,
			symbol_kind = 23,
		}),
		"type_conversion"
	)
end

T["references: A function passed as a value is a function argument"] = function()
	eq(
		classify_with_target({
			source = "package p\nfunc less(i, j int) bool { return true }\nfunc f(xs []int) { sort.Slice(xs, less) }",
			extension = "go",
			filetype = "go",
			target_line = 1,
			target_character = 5,
			usage_line = 2,
			usage_character = 34,
			symbol_kind = 12,
		}),
		"function_argument"
	)
end

T["references: A variable named by a type identifier is a type target"] = function()
	eq(
		classify_with_target({
			source = "package p\ntype Amount int\nfunc f(x int) { _ = Amount(x) }",
			extension = "go",
			filetype = "go",
			target_line = 1,
			target_character = 5,
			usage_line = 2,
			usage_character = 20,
			symbol_kind = 13,
		}),
		"type_conversion"
	)
end

T["references: Terraform blocks are not type targets"] = function()
	eq(
		classify_with_target({
			source = 'variable "region" {}\nvalue = var.region',
			extension = "tf",
			filetype = "terraform",
			target_line = 0,
			target_character = 9,
			usage_line = 1,
			usage_character = 12,
			symbol_kind = 5,
		}),
		"read"
	)
end

T["references: Function and type targets get no write or read"] = MiniTest.new_set()

T["references: Function and type targets get no write or read"]["function write is suppressed"] = function()
	eq(
		classify_with_target({
			source = "package p\nfunc run() {}\nfunc f() { _ = run }",
			extension = "go",
			filetype = "go",
			target_line = 1,
			target_character = 5,
			usage_line = 2,
			usage_character = 15,
			symbol_kind = 12,
			highlight = true,
		}),
		"unclassified"
	)
end

T["references: Function and type targets get no write or read"]["type write is suppressed"] = function()
	eq(
		classify_with_target({
			source = "package p\ntype Money int\nfunc f() { _ = Money }",
			extension = "go",
			filetype = "go",
			target_line = 1,
			target_character = 5,
			usage_line = 2,
			usage_character = 15,
			symbol_kind = 23,
			highlight = true,
		}),
		"unclassified"
	)
end

return T
