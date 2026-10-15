-- Core keymaps are registry actions; startup removes Neovim defaults, the registry re-adds adopted ones.
-- Grammar defaults (`Y`, `gc`, visual `*`, …) stay: lua/gleb/actions/audit.lua lists them.

local BRACKET_PAIRS =
	{ "b", "B", "t", "T", "<C-T>", "a", "A", "l", "L", "<C-L>", "q", "Q", "<C-Q>", "d", "D", "<Space>" }

---@type table<string, string[]>
local DEFAULTS = {
	n = { "gO", "gx", "<C-W>d", "<C-W><C-D>" },
	x = { "gra", "gx" },
	s = { "<C-S>" },
	i = { "<C-S>" },
}

for _, suffix in ipairs(BRACKET_PAIRS) do
	vim.list_extend(DEFAULTS.n, { "[" .. suffix, "]" .. suffix })
end

-- the `gr` LSP family (grn, gra, grr, gri, grt, grx, …) grows between Neovim releases
for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
	if mapping.lhs ~= "gr" and vim.startswith(mapping.lhs, "gr") then
		vim.keymap.del("n", mapping.lhs)
	end
end

for mode, lhs_list in pairs(DEFAULTS) do
	for _, lhs in ipairs(lhs_list) do
		if not vim.tbl_isempty(vim.fn.maparg(lhs, mode, false, true)) then
			vim.keymap.del(mode, lhs)
		end
	end
end
