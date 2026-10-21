-- Directory buffers are a file-tree entry point, so bootstrap the deferred lifecycle on their first BufEnter.

local group = vim.api.nvim_create_augroup("gleb_file_tree_loader", { clear = true })

---@param args vim.api.keyset.create_autocmd.callback_args
local function load_for_directory(args)
	local path = vim.api.nvim_buf_get_name(args.buf)
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	if vim.bo[args.buf].buftype ~= "" or not stat or stat.type ~= "directory" then
		return
	end
	vim.api.nvim_del_augroup_by_id(group)
	require("gleb.file_tree")
	vim.api.nvim_exec_autocmds("BufEnter", { buffer = args.buf })
end

vim.api.nvim_create_autocmd("BufEnter", {
	group = group,
	nested = true, -- loading installs the lifecycle handler, then replays this directory event for it
	callback = load_for_directory,
})
