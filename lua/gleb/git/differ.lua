local status_ok, differ = pcall(require, "differ")
if not status_ok then
	return
end

-- Mirrors the old diffview.lua preferences: side-by-side view, tree listing,
-- 35-wide panel on the left (same width as neo-tree).
differ.setup({
	layout = "split", -- "stacked" | "split"; toggle at runtime with `dl`
	context = 3, -- fold unchanged runs longer than this; `math.huge` = whole file
	panel = {
		position = "left",
		width = 35,
		listing = "tree",
	},
	deep_diff = {
		enabled = true,
		granularity = "word",
	},
})
