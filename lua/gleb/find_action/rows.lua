-- Find Action row metadata stays separate from picker rendering so filtering can reuse the same values.

local M = {}

---@type table<string, string>
local PHYSICAL_LABELS = {
	["<M-e>"] = "⌘E",
	["<M-g>"] = "⌘G",
	["<M-b>"] = "⌘B",
	["<M-q>"] = "⌘Q",
	["<M-Q>"] = "⌘⇧Q",
	["<M-r>"] = "⌘R",
	["<M-c>"] = "⌘C",
	["<M-/>"] = "⌘/",
	["<M-F>"] = "⌘⇧F",
	["<M-w>"] = "⌘W",
	["<M-W>"] = "⌘⇧W",
	["<C-H>"] = "⌘H",
	["<M-h>"] = "⌘⇧H",
	["<M-j>"] = "⌘⇧J",
	["<M-k>"] = "⌘⇧K",
	["<C-L>"] = "⌘L",
	["<M-l>"] = "⌘⇧L",
	["<M-->"] = "⌘-",
	["<M-=>"] = "⌘=",
	["<S-D-->"] = "⌘⇧-",
	["<S-D-=>"] = "⌘⇧=",
	["<M-9>"] = "⌘9",
	["<S-CR>"] = "⇧↩",
	["<M-}>"] = "⌥↩",
	["<M-{>"] = "⌥⇧↩",
	["<M-%>"] = "⌥F",
	["<M-!>"] = "⌥H",
	["<M-#>"] = "⌥J",
	["<M-$>"] = "⌥K",
	["<M-@>"] = "⌥L",
	["<M-^>"] = "⌥⇧H",
	["<M-*>"] = "⌥⇧J",
	["<M-(>"] = "⌥⇧K",
	["<M-&>"] = "⌥⇧L",
	["<M-Ω>"] = "⌃⌥H",
	["<M-ç>"] = "⌃⌥J",
	["<M-∫>"] = "⌃⌥K",
	["<M-≈>"] = "⌃⌥L",
	["<C-CR>"] = "⌃↩",
	["<C-Up>"] = "⌃↑",
	["<C-Down>"] = "⌃↓",
	["<C-Left>"] = "⌃←",
	["<C-Right>"] = "⌃→",
	["<D-o>"] = "⌘O",
	["<D-i>"] = "⌘I",
	["<D-d>"] = "⌘D",
	["<D-a>"] = "⌘A",
	["<M-A>"] = "⌘⇧A",
}

---@param lhs string
---@return string
function M.physical_label(lhs)
	return PHYSICAL_LABELS[lhs] or lhs
end

---@param action gleb.Action
---@param shortcuts? string[]
---@param toggle_state? boolean
---@return gleb.picker.Row
function M.format(action, shortcuts, toggle_state)
	---@type gleb.picker.Row
	local row = {
		text = action.title,
		category = action.category,
	}
	if shortcuts and shortcuts[1] then
		row.secondary = M.physical_label(shortcuts[1])
	end
	if toggle_state ~= nil then
		row.glyph = toggle_state
	end
	return row
end

return M
