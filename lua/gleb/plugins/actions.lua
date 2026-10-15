-- lazy.nvim window actions; filetype-scoped, so the registry maps them in the `lazy` float.

local function close_lazy()
	local view = require("lazy.view").view
	if view then
		view:close()
	end
end

---@type gleb.Action[]
local actions = {
	{ id = "lazy.close", title = "Close Lazy", category = "Lazy", ft = "lazy", run = close_lazy },
}

return actions
