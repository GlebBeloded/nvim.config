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

local function vibe_prompt()
	enter_prompt(nn.vibe)
end

local function visual_prompt()
	enter_prompt(nn.visual)
end

---Map the direct 99 entry keys: Shift-Enter vibe and the visual prompts.
---@param ninety_nine gleb.ai.Actions the 99 module (or a stub with the same actions)
---@return nil
function M.setup(ninety_nine)
	nn = ninety_nine
	vim.keymap.set("n", "<S-CR>", vibe_prompt, { silent = true, desc = "99: Vibe" })
	vim.keymap.set("x", "<A-9>", visual_prompt, { silent = true, desc = "99: Visual" })
	vim.keymap.set("x", "<S-CR>", visual_prompt, { silent = true, desc = "99: Visual" })
end

return M
