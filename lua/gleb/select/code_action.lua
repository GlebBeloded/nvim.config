local Menu = require("nui.menu")

-- Meta class
local codeAction = {}

-- @returns lib
function codeAction:new(items, opts, on_choice)
	local l = {}

	setmetatable(l, self)
	self.__index = self
	l.items = items
	l.opts = opts
	l.on_choice = on_choice

	return l
end

function codeAction:defaultKeymap()
	return {
		focus_next = { "j", "<Down>", "<Tab>" },
		focus_prev = { "k", "<Up>", "<S-Tab>" },
		close = { "<Esc>", "<C-c>" },
		submit = { "<CR>", "<Space>" },
	}
end

function codeAction:popupName()
	return self.opts.prompt
end

-- @return nubmer
function codeAction:longestEntryLength()
	local length = 255

	-- for _, value in pairs(self.items) do
	-- 	if #value[2].title > length then
	-- 		length = #value[2].title
	-- 	end
	-- end

	return length
end

-- popupUnderCursorOptions returns popupOptions for menu under cursor
function codeAction:popupUnderCursorOptions()
	return {
		position = {
			row = 1, -- 1 row below the code action
			col = 0,
		},
		relative = "cursor",
		size = {
			width = self:longestEntryLength(),
		},
		border = {
			style = "single",
			text = {
				top = self:popupName(),
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	}
end

function codeAction:menu()
	local options = {}
	for key, value in pairs(self.items) do
		table.insert(options, Menu.item(value[2].title, { index = key, data = value }))
	end

	return {
		lines = { unpack(options) },
		max_width = 20,
		keymap = codeAction.keymap,
		on_submit = function(item)
			self.on_choice(item.data, item.key)
		end,
	}
end

-- this functions draws menu window
function codeAction:select()
	-- mount the component
	Menu(self:popupUnderCursorOptions(), self:menu()):mount()
end

return codeAction
