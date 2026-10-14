-- Core keymaps are registry actions; startup only removes conflicting long `gr` defaults.

for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
	if mapping.lhs ~= "gr" and vim.startswith(mapping.lhs, "gr") then
		vim.keymap.del("n", mapping.lhs)
	end
end
