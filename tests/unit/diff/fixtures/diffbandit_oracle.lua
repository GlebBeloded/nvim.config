-- Translated from diffbandit.nvim (Apache-2.0, © Corey Kaylor) at 7e1e5b8b:
-- tests/specs/40_oracle.lua, captured from IntelliJ util-diff 261.26222.72.
-- Modified: 1-based hunks rewritten as 0-based, half-open Lua fixture data; see lua/gleb/diff/engine/NOTICE.
return {
	{
		source = "40_oracle.lua:iw-realign",
		lines1 = { ".{", "..{", "...{" },
		lines2 = { "..{", "...{" },
		fragments = { { 0, 1, 0, 0 } },
	},
	{
		source = "40_oracle.lua:blank-line slide",
		lines1 = { "fun a() {", "    body", "}", "", "fun c() {", "    body", "}" },
		lines2 = {
			"fun a() {",
			"    body",
			"}",
			"",
			"fun b() {",
			"    body",
			"}",
			"",
			"fun c() {",
			"    body",
			"}",
		},
		fragments = { { 4, 4, 4, 8 } },
	},
	{
		source = "40_oracle.lua:unimportant-line anchoring",
		lines1 = { "alpha one", "{", "}", "", "beta two", "{", "}" },
		lines2 = { "gamma three", "{", "}", "", "alpha one", "{", "}", "", "beta two", "{", "}" },
		fragments = { { 0, 0, 0, 4 } },
	},
	{
		source = "40_oracle.lua:block reorder",
		lines1 = { "aa bb", "cc dd", "ee ff", "gg hh" },
		lines2 = { "ee ff", "gg hh", "aa bb", "cc dd" },
		fragments = { { 0, 2, 0, 0 }, { 4, 4, 2, 4 } },
	},
	{
		source = "40_oracle.lua:word sub-blocks",
		lines1 = { "val x = compute(a, b)", "return x" },
		lines2 = { "val x = compute(a, b, c)", "log(x)", "return x" },
		fragments = { { 0, 1, 0, 2 } },
	},
}
