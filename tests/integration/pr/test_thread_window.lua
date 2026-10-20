local H = require("tests.helpers")

local child = H.new_child()
local T = H.child_set(child, child.start_config)

T["pr: Thread window colours"] = function()
	child.cmd("colorscheme gruvbox-material")

	H.expect_hl_colors(child, "PrConfirm", { fg = "#d8a657", bg = "#4b4131", bold = true })
	H.expect_hl_colors(child, "PrConfirmHint", { fg = "#ddc7a1", bg = "#4b4131" })
	H.expect_hl_colors(child, "PrReplyPlaceholder", { fg = "#7c6f64", italic = true })
end

return T
