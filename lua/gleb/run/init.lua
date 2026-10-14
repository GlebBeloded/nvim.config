local function cargo_root()
	return vim.fs.root(0, "Cargo.toml")
end

vim.api.nvim_create_user_command("Run", function()
	-- if directory contains index.html, open it in browser
	if vim.fn.filereadable("index.html") == 1 then
		vim.cmd("silent !open -a Safari index.html")
	elseif vim.fn.filereadable("Cargo.lock") == 1 then
		vim.cmd("!cd " .. vim.fn.shellescape(cargo_root(), true) .. " && cargo run")
	end
end, { range = false })
