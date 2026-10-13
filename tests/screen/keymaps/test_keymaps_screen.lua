-- Reference screenshot of `<C-q>` closing a buffer shown in a split (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local H = require("tests.helpers")
local cases = require("tests.render.cases")

local child = H.new_child()

local function start()
	child.start_config()
	child.o.lines, child.o.columns = 12, 80
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["keymaps: Close buffer in split matches reference screenshot"] = function()
	cases["close-buffer-split"].setup(child)
	vim.uv.sleep(300) -- let timers (lualine, bufferline) redraw
	H.expect_screenshot(child.get_screenshot())
end

return T
