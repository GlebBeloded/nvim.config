-- The PR statusline component is cache-only so redraw never starts Git or GitHub work.

local M = {}

local PR_ICON = ""
local THREAD_ICON = "󰆈"

---@return string?
local function current_root()
	local base = package.loaded["gleb.git.base"]
	if not base then
		return nil
	end
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or vim.bo.buftype ~= "" then
		path = vim.fn.getcwd()
	end
	path = vim.fs.normalize(path)
	local best
	for root in pairs(base.state.roots) do
		local relative = vim.fs.relpath(root, path)
		if relative and relative ~= ".." and relative:sub(1, 3) ~= "../" and (not best or #root > #best) then
			best = root
		end
	end
	return best
end

---@return string
function M.component()
	local root = current_root()
	local base = package.loaded["gleb.git.base"]
	local pr = package.loaded["gleb.pr"]
	local info = root and base and base.get(root) or nil
	if not info or not info.pr then
		return ""
	end
	local text = ("%%#lualine_b_normal# %%#PrStatuslineNumber#%s #%d"):format(PR_ICON, info.pr.number)
	local review = pr and pr.get(root) or nil
	local count = review and require("gleb.pr.threads").open_count(review.threads) or 0
	if count > 0 then
		text = text .. ("%%#lualine_b_normal#  %%#PrStatuslineThreads#%s %d"):format(THREAD_ICON, count)
	end
	return text
end

--- lualine's `branch` finds no repository for a non-file buffer such as the Changes panel: with a pull request,
--- fall back to the cached branch of the root, so the pull request still follows its branch.
---@param status string lualine's branch
---@return string
function M.branch(status)
	local root = status == "" and current_root() or nil
	local base = package.loaded["gleb.git.base"]
	local info = root and base and base.get(root) or nil
	return info and info.pr and info.branch or status
end

---@return boolean
function M.cond()
	return M.component() ~= ""
end

return M
