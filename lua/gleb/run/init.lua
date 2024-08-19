local function git_root()
	local dot_git_path = vim.fn.finddir(".git", ".;")
	return vim.fn.fnamemodify(dot_git_path, ":h")
end

vim.api.nvim_create_user_command("Run", function()
	-- if directory contains index.html, open it in browser
	if vim.fn.filereadable("index.html") == 1 then
		vim.cmd("silent !open -a Safari index.html")
	elseif vim.fn.filereadable("Cargo.lock") then
		vim.cmd("!cd " .. git_root() .. ";cargo run")
	end
end, { range = false })
