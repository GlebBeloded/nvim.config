-- Reference screenshot of the shared wide picker frame.
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality

local ITEMS = {
	{ text = "config matches", section = true },
	{ text = "vim.ui.select = function", secondary = "lua/gleb/select/init.lua:6", category = "Config" },
	{ text = "one shared picker UI", secondary = "openspec/changes/picker-ui/proposal.md:9", category = "UI" },
	{ text = 'require("gleb.picker")', secondary = "init.lua:17", category = "Startup" },
}

local function start()
	child.start_bare({ "gruvbox-material" })
	child.o.lines = 24
	child.o.columns = 80
	child.cmd("colorscheme gruvbox-material")
end

local T = H.child_set(child, start)

T["picker: Wide picker matches reference screenshot"] = function()
	local loaded = child.lua_get([[(function()
		local ok, picker = pcall(require, "gleb.picker")
		if ok then Picker = picker end
		return ok
	end)()]])
	eq(loaded, true)

	child.lua_notify(
		[[Picker.start({
		title = "Live Grep",
		items = ...,
		hints = "Open ↩ · Split ⌃S · Vsplit ⌃V",
		match = function(_, inds) return inds end,
	})]],
		{ ITEMS }
	)
	assert(child.wait([[require("mini.pick").is_picker_active()]]), "shared picker did not open")
	child.type_keys("picker<Down>")
	assert(child.wait([[table.concat(require("mini.pick").get_picker_query()) == "picker"]]), "query was not rendered")

	H.expect_hl_colors(child, "MiniPickBorder", { fg = "#45403d" })
	H.expect_hl_colors(child, "MiniPickNormal", { fg = "#ddc7a1", bg = "#282828" })
	H.expect_hl_colors(child, "MiniPickMatchCurrent", { bg = "#32302f" })
	H.expect_hl_colors(child, "PickerHint", { fg = "#5a524c" })
	H.expect_screenshot(child.get_screenshot())
	child.type_keys("<Esc>")
end

return T
