-- AI actions expose 99's normal prompts without loading the lazy plugin at startup.

---@param action "search"|"vibe"
local function open_prompt(action)
	require("99")[action]()
	vim.schedule(vim.cmd.startinsert)
end

---@type gleb.Action[]
local actions = {
	{
		id = "ai.search",
		title = "99 Search",
		category = "AI",
		run = function()
			open_prompt("search")
		end,
	},
	{
		id = "ai.vibe",
		title = "99 Vibe",
		category = "AI",
		run = function()
			open_prompt("vibe")
		end,
	},
}

return actions
