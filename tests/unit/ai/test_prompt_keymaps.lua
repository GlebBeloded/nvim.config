local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		local catalog = require("gleb.actions").catalog({ require("gleb.ai.actions") })
		PromptKeymaps = require("gleb.actions.apply").new(catalog)
	]])
end

local function apply_prompt_keymaps()
	child.lua([[PromptKeymaps:apply({ ["ai.submit_prompt"] = { "<S-CR>" } })]])
end

---@param filetype string
local function new_buffer(filetype)
	child.cmd("enew")
	child.bo.filetype = filetype
end

local T = H.child_set(child, start)

T["ai: submits with Shift+Enter in normal and insert modes"] = function()
	apply_prompt_keymaps()
	new_buffer("99")
	child.api.nvim_buf_set_name(0, vim.fn.tempname() .. ".prompt")
	child.bo.buftype = "acwrite"
	child.lua([[
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = 0,
			callback = function() vim.g.ai_submit_count = (vim.g.ai_submit_count or 0) + 1 end,
		})
	]])
	child.type_keys("<S-CR>i<S-CR>")

	eq(child.lua_get([[vim.g.ai_submit_count]]), 2)
end

T["ai: Submit mapping is buffer-local"] = function()
	apply_prompt_keymaps()
	new_buffer("99")
	new_buffer("lua")

	eq(child.lua_get([[vim.fn.maparg("<S-CR>", "n", false, true).buffer]]), vim.NIL)
	eq(child.fn.maparg("<S-CR>", "n"), "")
end

T["ai: Setup is idempotent"] = function()
	apply_prompt_keymaps()
	apply_prompt_keymaps()

	eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = "gleb_actions_bindings", event = "FileType" })]]), 1)
end

return T
