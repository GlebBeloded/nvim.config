-- Repairs query links left pointing outside the installed nvim-treesitter plugin.
local M = {}

---@param path string
---@param root string
---@return boolean
local function is_below(path, root)
	return path:sub(1, #root + 1) == root .. "/"
end

---@param link string
---@return string?
local function link_target(link)
	local target = vim.uv.fs_readlink(link)
	if not target then
		return nil
	end
	if target:sub(1, 1) ~= "/" then
		target = vim.fs.joinpath(vim.fs.dirname(link), target)
	end
	return vim.fs.normalize(target)
end

---@param link string
---@param replacement string
---@return boolean
local function repair_link(link, replacement)
	local unlinked, unlink_error = vim.uv.fs_unlink(link)
	if not unlinked then
		vim.notify("Treesitter query link repair failed for " .. link .. ": " .. unlink_error, vim.log.levels.WARN)
		return false
	end

	local linked, link_error = vim.uv.fs_symlink(replacement, link)
	if not linked then
		vim.notify("Treesitter query link repair failed for " .. link .. ": " .. link_error, vim.log.levels.WARN)
		return false
	end

	return true
end

---@param site string
---@param plugin string
function M.repair(site, plugin)
	local queries = vim.fs.joinpath(site, "queries")
	local plugin_queries = vim.fs.normalize(vim.fs.joinpath(plugin, "runtime/queries"))
	local scan = vim.uv.fs_scandir(queries)
	if not vim.uv.fs_stat(plugin_queries) or not scan then
		return
	end

	local repaired = {}
	while true do
		local name = vim.uv.fs_scandir_next(scan)
		if not name then
			break
		end
		local link = vim.fs.joinpath(queries, name)
		local stat = vim.uv.fs_lstat(link)
		local target = stat and stat.type == "link" and link_target(link) or nil
		local resolved = target and vim.uv.fs_realpath(link) or nil
		local replacement = vim.fs.joinpath(plugin_queries, name)
		if
			stat
			and stat.type == "link"
			and (not target or not resolved or not is_below(target, plugin_queries))
			and vim.uv.fs_stat(replacement)
		then
			if repair_link(link, replacement) then
				table.insert(repaired, name)
			end
		end
	end

	if #repaired > 0 then
		table.sort(repaired)
		vim.notify("Repaired Treesitter query links: " .. table.concat(repaired, ", "), vim.log.levels.INFO)
	end
end

return M
