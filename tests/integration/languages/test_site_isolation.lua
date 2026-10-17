local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local site_before

---@param root string
---@return table[]
local function snapshot(root)
	local entries = {}
	local function visit(dir, prefix)
		local handle = vim.uv.fs_scandir(dir)
		if not handle then
			return
		end
		while true do
			local name = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local path = vim.fs.joinpath(dir, name)
			local relative = prefix == "" and name or vim.fs.joinpath(prefix, name)
			local stat = assert(vim.uv.fs_lstat(path))
			table.insert(entries, {
				path = relative,
				type = stat.type,
				mtime = stat.mtime,
				target = vim.uv.fs_readlink(path) or vim.NIL,
			})
			if stat.type == "directory" then
				visit(path, relative)
			end
		end
	end
	visit(root, "")
	table.sort(entries, function(a, b)
		return a.path < b.path
	end)
	return entries
end

local function start()
	site_before = snapshot(vim.fs.joinpath(H.data_dir, "site"))
	local args = H.config_args()
	table.insert(args, 5, "--cmd")
	table.insert(
		args,
		6,
		[[lua GlebTestNotifications = {}; vim.notify = function(msg, level) table.insert(GlebTestNotifications, { msg = msg, level = level }) end; local language = require("gleb.languages.terraform"); table.insert(language.treesitter.parsers, "gleb_test_missing"); package.preload["nvim-treesitter"] = function() return { install = function(parsers) vim.g.gleb_test_install = vim.deepcopy(parsers) end } end]]
	)
	child.restart(args)
	vim.iter(H.DISABLED_PLUGINS):each(child.disable_plugin)
end

local T = H.child_set(child, start)

T["languages: A test child leaves the host site untouched"] = function()
	local site = vim.fs.joinpath(H.data_dir, "site")
	local installer_ran = child.lua_get([[vim.g.gleb_test_install ~= nil]])
	local warnings = child.lua_get([[
		vim.tbl_filter(function(notification)
			return notification.level == vim.log.levels.WARN
	end, GlebTestNotifications)
	]])
	local after = snapshot(site)

	eq(after, site_before)
	eq(installer_ran, false)
	eq(warnings, {
		{ msg = "Missing Treesitter parsers: gleb_test_missing", level = vim.log.levels.WARN },
	})
end

return T
