-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/issue-204948/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		'    "@babel/types" "^7.22.15"',
		"",
		'"@babel/traverse@^7.23.9":',
		'  version "7.23.9"',
		'  resolved "https://registry.yarnpkg.com/@babel/traverse/-/traverse-7.23.7.tgz#9a7bf285c928cb99b5ead19c3b1ce5b310c9c305"',
		"  integrity sha512-tY3mM8rH9jM0YHFGyfC0/xf+SB5eKUu7HPj7/k3fpi9dAlsMc5YbQvDi0Sh2QTPXqMhyaAtzAr807TIyfQrmyg==",
		"  dependencies:",
		'    "@babel/code-frame" "^7.23.5"',
		'    "@babel/generator" "^7.23.6"',
	},
	lines2 = {
		'    "@babel/types" "^7.22.15"',
		"",
		'"@babel/traverse@^7.23.9":',
		'  version "7.23.9"',
		'  resolved "https://registry.yarnpkg.com/@babel/traverse/-/traverse-7.23.7.tgz#9a7bf285c928cb99b5ead19c3b1ce5b310c9c305"',
		"  integrity sha512-I/4UJ9vs90OkBtY6iiiTORVMyIhJ4kAVmsKo9KFc8UOxMeUfi2hvtIBsET5u9GizXE6/GFSuKCTNfgCswuEjRg==",
		"  dependencies:",
		'    "@babel/code-frame" "^7.23.5"',
		'    "@babel/generator" "^7.23.6"',
	},
	trim_ws = false,
	changes = {
		{ 5, 6, 5, 6 },
	},
	moves = {},
}
