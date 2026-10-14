local Menu = require("nui.menu")

-- Meta class
local code_action = {}

-- @returns lib
function code_action:new(items, opts, on_choice)
	local l = {}

	setmetatable(l, self)
	self.__index = self
	l.items = items
	l.opts = opts
	l.on_choice = on_choice

	return l
end

function code_action:default_keymap()
	return {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	}
end

function code_action:popup_name()
	return self.opts.prompt
end

-- @return number
function code_action:longest_entry_length()
	return 255
end

-- popup_under_cursor_options returns popup_options for menu under cursor
function code_action:popup_under_cursor_options()
	return {
		position = {
			row = 1, -- 1 row below the code action
			col = 0,
		},
		relative = "cursor",
		size = {
			width = self:longest_entry_length(),
		},
		border = {
			style = "single",
			text = {
				top = self:popup_name(),
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	}
end

function code_action:menu()
	local options = {}
	for key, value in pairs(self.items) do
		local text = self.opts.format_item and self.opts.format_item(value) or tostring(value)
		table.insert(options, Menu.item(text, { index = key, data = value }))
	end

	return {
		lines = { unpack(options) },
		max_width = 20,
		keymap = self:default_keymap(),
		on_submit = function(item)
			self.on_choice(item.data, item.index)
		end,
		on_close = function()
			self.on_choice(nil, nil)
		end,
	}
end

-- this functions draws menu window
function code_action:select()
	-- mount the component
	Menu(self:popup_under_cursor_options(), self:menu()):mount()
end

return code_action
