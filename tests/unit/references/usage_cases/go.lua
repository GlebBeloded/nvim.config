return {
	filetype = "go",
	source = "package p\nfunc total() {}\nfunc use() { total() }",
	cases = {
		{ line = 2, character = 13, expected = "call" },
	},
}
