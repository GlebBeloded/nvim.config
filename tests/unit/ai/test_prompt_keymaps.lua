local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[PromptKeymaps = require("gleb.ai.prompt_keymaps")]])
end

---@param filetype string
local function new_buffer(filetype)
	child.cmd("enew")
	child.bo.filetype = filetype
end

local T = H.child_set(child, start)

T["ai: submits with Shift+Enter in normal and insert modes"] = function()
	child.lua("PromptKeymaps.setup()")
	new_buffer("99")

	eq(child.fn.maparg("<S-CR>", "n"), "<Cmd>write<CR>")
	eq(child.fn.maparg("<S-CR>", "i"), "<Cmd>write<CR>")
end

T["ai: Submit mapping is buffer-local"] = function()
	child.lua("PromptKeymaps.setup()")
	new_buffer("99")
	new_buffer("lua")

	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "n", false, true).buffer]]), vim.NIL)
	eq(child.fn.maparg("<S-CR>", "n"), "")
end

T["ai: Setup is idempotent"] = function()
	child.lua("PromptKeymaps.setup(); PromptKeymaps.setup()")

	eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = "gleb_ai_prompt_keymaps" })]]), 1)
end

return T
