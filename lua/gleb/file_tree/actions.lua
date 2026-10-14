-- File-tree entry actions preserve the source-aware toggle behavior without owning keys.

---@param source string
---@param current_source string
local function apply_toggle(source, current_source)
	if current_source == source then
		vim.cmd("Neotree close")
	else
		vim.cmd("Neotree " .. source)
	end
end

---@param callback function
local function after_pending_filesystem_render(callback)
	local state = require("neo-tree.sources.manager").get_state("filesystem")
	local events = require("neo-tree.events")
	local render_generation = 0
	local finished = false
	local subscription
	local function finish()
		if finished then
			return
		end
		finished = true
		events.unsubscribe(subscription)
		callback()
	end
	local function finish_after_debounce()
		render_generation = render_generation + 1
		local expected_generation = render_generation
		vim.defer_fn(function()
			if expected_generation == render_generation and state._ready ~= false then
				finish()
			end
		end, 120)
	end
	subscription = {
		event = events.AFTER_RENDER,
		handler = function(rendered_state)
			if rendered_state == state then
				finish_after_debounce()
			end
		end,
	}
	events.subscribe(subscription)
	finish_after_debounce()
	vim.defer_fn(finish, 5000)
end

---@param source string
local function smart_toggle(source)
	local current_buf = vim.api.nvim_get_current_buf()
	if vim.bo[current_buf].filetype == "neo-tree" then
		local current_source = vim.api.nvim_buf_get_name(current_buf):match("neo%-tree ([%w_]+)")
		if current_source == "filesystem" then
			after_pending_filesystem_render(function()
				apply_toggle(source, current_source)
			end)
		else
			apply_toggle(source, current_source)
		end
	elseif source == "filesystem" then
		local current_file = vim.fn.expand("%:p")
		if current_file ~= "" and not current_file:match("^%w+://") then
			vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(current_file) .. " filesystem")
		else
			require("neo-tree.command").execute({ source = "filesystem", action = "focus", reveal = false })
		end
	else
		vim.cmd("Neotree focus " .. source)
	end
end

---@type gleb.Action[]
local actions = {
	{
		id = "tree.toggle_filesystem",
		title = "Toggle filesystem",
		category = "Tree",
		run = function()
			smart_toggle("filesystem")
		end,
	},
	{
		id = "tree.toggle_git_status",
		title = "Toggle git status",
		category = "Tree",
		run = function()
			smart_toggle("git_status")
		end,
	},
}

return actions
