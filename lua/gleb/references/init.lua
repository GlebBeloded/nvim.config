-- Find Usages captures the symbol before the asynchronous request and opens its dedicated view.
local M = {}

local request = require("gleb.references.request")
local kind = require("gleb.references.kind")
local view = require("gleb.references.view")

---@return nil
function M.open()
	local symbol = vim.fn.expand("<cword>")
	request.start(function(usages)
		local view_id = view.open(symbol, usages, true)
		kind.classify(usages, function(classified)
			view.finish_classification(view_id, classified)
		end)
	end)
end

return M
