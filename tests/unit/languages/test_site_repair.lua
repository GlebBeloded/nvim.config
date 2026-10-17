local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local notifications

local function start()
	child.start_bare()
	notifications = H.record_notify(child)
end

local T = H.child_set(child, start)

---@return string, string
local function make_site()
	local root = H.tempdir(child)
	local site = vim.fs.joinpath(root, "site")
	local plugin = vim.fs.joinpath(root, "nvim-treesitter")
	child.lua(
		[[
			local site, plugin = ...
			vim.fn.mkdir(vim.fs.joinpath(site, "queries"), "p")
			vim.fn.mkdir(vim.fs.joinpath(plugin, "runtime/queries/hcl"), "p")
			vim.fn.mkdir(vim.fs.joinpath(plugin, "runtime/queries/go"), "p")
			vim.fn.mkdir(vim.fs.joinpath(plugin, "lua/nvim-treesitter"), "p")
			vim.fn.writefile({ "return {}" }, vim.fs.joinpath(plugin, "lua/nvim-treesitter/init.lua"))
		]],
		{ site, plugin }
	)
	return site, plugin
end

local function repair(site, plugin)
	child.lua([[require("gleb.treesitter.repair").repair(...)]], { site, plugin })
end

local dangling_scenario = "languages: A dangling query link is repaired on start"
T[dangling_scenario] = MiniTest.new_set()

T[dangling_scenario]["repairs the dangling link"] = function()
	local site, plugin = make_site()
	local link = vim.fs.joinpath(site, "queries/hcl")
	local target = vim.fs.joinpath(plugin, "runtime/queries/hcl")
	child.lua([[assert(vim.uv.fs_symlink(...))]], { vim.fs.joinpath(site, "missing/hcl"), link })

	repair(site, plugin)

	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { link }), target)
	eq(notifications(), { { msg = "Repaired Treesitter query links: hcl", level = vim.log.levels.INFO } })
end

T[dangling_scenario]["runs repair before the installer"] = function()
	local _, plugin = make_site()
	child.lua(
		[[
			local plugin = ...
			vim.env.GLEB_TEST_SANDBOX = nil
			RepairOrder = {}
			package.loaded["gleb.treesitter.repair"] = {
				repair = function()
					table.insert(RepairOrder, "repair")
				end,
			}
			package.preload["nvim-treesitter"] = function()
				vim.opt.runtimepath:append(plugin)
				return {
					install = function()
						table.insert(RepairOrder, "install")
					end,
				}
			end
			require("gleb.treesitter")
		]],
		{ plugin }
	)

	eq(child.lua_get([[RepairOrder]]), { "repair", "install" })
end

local outside_scenario = "languages: A query link outside the plugin is repaired"
T[outside_scenario] = MiniTest.new_set()

T[outside_scenario]["repairs a link to another directory"] = function()
	local site, plugin = make_site()
	local link = vim.fs.joinpath(site, "queries/hcl")
	local target = vim.fs.joinpath(plugin, "runtime/queries/hcl")
	local outside = vim.fs.joinpath(site, "outside/hcl")
	child.lua(
		[[
			local outside, link = ...
			vim.fn.mkdir(outside, "p")
			assert(vim.uv.fs_symlink(outside, link))
		]],
		{ outside, link }
	)

	repair(site, plugin)

	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { link }), target)
end

T[outside_scenario]["repairs a temporary path that resolves into the plugin"] = function()
	local site, plugin = make_site()
	local link = vim.fs.joinpath(site, "queries/hcl")
	local target = vim.fs.joinpath(plugin, "runtime/queries/hcl")
	local alias = vim.fs.joinpath(site, "temporary-plugin")
	child.lua(
		[[
			local plugin, alias, link = ...
			assert(vim.uv.fs_symlink(plugin, alias))
			assert(vim.uv.fs_symlink(vim.fs.joinpath(alias, "runtime/queries/hcl"), link))
		]],
		{ plugin, alias, link }
	)

	repair(site, plugin)

	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { link }), target)
end

T["languages: Valid links and real folders are left alone"] = function()
	local site, plugin = make_site()
	local go_link = vim.fs.joinpath(site, "queries/go")
	local go_target = vim.fs.joinpath(plugin, "runtime/queries/go")
	local custom = vim.fs.joinpath(site, "queries/custom")
	child.lua(
		[[
			local target, link, custom = ...
			assert(vim.uv.fs_symlink(target, link))
			vim.fn.mkdir(custom, "p")
			vim.fn.writefile({ "keep" }, vim.fs.joinpath(custom, "after"))
		]],
		{ go_target, go_link, custom }
	)

	repair(site, plugin)

	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { go_link }), go_target)
	eq(child.lua_get([[vim.fn.readfile(vim.fs.joinpath(..., "after"))]], { custom }), { "keep" })
	eq(notifications(), {})
end

return T
