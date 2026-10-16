-- Find Usages captures the symbol before the asynchronous request and opens its dedicated view.
local M = {}

local request = require("gleb.references.request")
local view = require("gleb.references.view")

---@return nil
function M.open()
	local symbol = vim.fn.expand("<cword>")
	request.start(function(usages)
		view.open(symbol, usages)
	end)
end

return M
