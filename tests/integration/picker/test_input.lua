local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.lua([[
		_G.input_submissions = {}
		_G.open_input = function(opts)
			vim.schedule(function()
				require("gleb.picker.input").open(vim.tbl_extend("force", {
					title = "New File or Directory",
					hint = "Create ↩",
					preview = function(query)
						return { text = "internal/billing/" .. query }
					end,
					on_submit = function(query)
						table.insert(_G.input_submissions, query)
					end,
				}, opts or {}))
			end)
		end
	]])
end

local function open_input(opts)
	child.lua("_G.open_input(...)", { opts or {} })
	assert(child.wait("MiniPick.is_picker_active()"), "Input picker did not open")
end

local function picker_line()
	return child.lua_get([[
		vim.api.nvim_buf_get_lines(MiniPick.get_picker_state().buffers.main, 0, 1, false)[1]
	]])
end

local T = H.child_set(child, start)

T["picker: Input prompt submits its query"] = function()
	open_input()
	child.type_keys("fee.go", "<CR>")

	assert(child.wait("not MiniPick.is_picker_active()"), "Input picker did not close")
	assert(child.wait("#_G.input_submissions == 1"), "Input submission did not run")
	eq(child.lua_get("_G.input_submissions"), { "fee.go" })
end

T["picker: Input prompt starts with its default and previews it"] = function()
	open_input({ default = "invoice.go" })

	eq(child.lua_get("table.concat(MiniPick.get_picker_query())"), "invoice.go")
	eq(picker_line(), " internal/billing/invoice.go")
	child.type_keys("x")
	assert(
		child.wait(
			[[vim.api.nvim_buf_get_lines(MiniPick.get_picker_state().buffers.main, 0, 1, false)[1] == " internal/billing/invoice.gox"]]
		),
		"Preview did not update"
	)
end

T["picker: Input prompt cancels with Esc"] = function()
	open_input()
	child.type_keys("fee.go", "<Esc>")

	assert(child.wait("not MiniPick.is_picker_active()"), "Input picker did not close")
	eq(child.lua_get("_G.input_submissions"), {})
end

T["picker: Input prompt ignores a blank query"] = function()
	open_input()
	child.type_keys("  ", "<CR>")

	eq(child.lua_get("MiniPick.is_picker_active()"), true)
	eq(child.lua_get("_G.input_submissions"), {})
end

return T
