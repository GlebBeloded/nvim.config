local M = {}

---@class gleb.ai.Actions
---@field search fun()
---@field vibe fun()
---@field visual fun()

---@type gleb.ai.Actions
local nn

---@param action fun()
local function enter_prompt(action)
	action()
	vim.schedule(vim.cmd.startinsert)
end

local function normal_menu()
	local cmdheight = vim.o.cmdheight
	vim.o.cmdheight = 1
	vim.api.nvim_echo({ { "99> [s]earch [v]ibe: ", "Question" } }, false, {})
	local key = vim.fn.getcharstr()
	vim.o.cmdheight = cmdheight
	vim.cmd("redraw")
	local actions = { s = nn.search, v = nn.vibe }
	if actions[key] then
		enter_prompt(actions[key])
	end
end

local function vibe_prompt()
	enter_prompt(nn.vibe)
end

local function visual_prompt()
	enter_prompt(nn.visual)
end

---Map the 99 entry keys: the normal-mode menu, Shift-Enter vibe and the visual prompts.
---@param ninety_nine gleb.ai.Actions the 99 module (or a stub with the same actions)
---@return nil
function M.setup(ninety_nine)
	nn = ninety_nine
	vim.keymap.set("n", "<A-9>", normal_menu, { silent = true, desc = "99: Menu" })
	vim.keymap.set("n", "<S-CR>", vibe_prompt, { silent = true, desc = "99: Vibe" })
	vim.keymap.set("x", "<A-9>", visual_prompt, { silent = true, desc = "99: Visual" })
	vim.keymap.set("x", "<S-CR>", visual_prompt, { silent = true, desc = "99: Visual" })
end

return M
