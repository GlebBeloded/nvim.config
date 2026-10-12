-- A small Lua file in Normal mode (no LSP, outside git): buffer, bufferline, statusline.
---@param child test.Child
return function(child)
	child.lua([[vim.lsp.enable("lua_ls", false)]])
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(
		{ "local M = {}", "", "function M.hello()", '  return "world"', "end", "", "return M" },
		dir .. "/sample.lua"
	)
	child.cmd("cd " .. dir .. " | edit sample.lua")
end
