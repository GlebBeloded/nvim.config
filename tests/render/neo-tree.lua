-- Neo-tree filesystem tree of this checkout next to an empty buffer.
local H = require("tests.helpers")

---@param child test.Child
return function(child)
	child.cmd("cd " .. H.root .. " | enew | Neotree filesystem")
	child.wait([[vim.bo.filetype == "neo-tree"]], 3000)
end
