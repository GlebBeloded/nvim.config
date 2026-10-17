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

local unwritable_scenario = "languages: An unwritable query link does not break startup"
T[unwritable_scenario] = MiniTest.new_set()

T[unwritable_scenario]["warns and repairs the next link"] = function()
	local site, plugin = make_site()
	local failed_link = vim.fs.joinpath(site, "queries/hcl")
	local repairable_link = vim.fs.joinpath(site, "queries/go")
	local repairable_target = vim.fs.joinpath(plugin, "runtime/queries/go")
	child.lua(
		[[
			local failed_link, repairable_link = ...
			assert(vim.uv.fs_symlink("/read-only/hcl", failed_link))
			assert(vim.uv.fs_symlink("/missing/go", repairable_link))
			local unlink = vim.uv.fs_unlink
			vim.uv.fs_unlink = function(path)
				if path == failed_link then
					return nil, "EACCES: permission denied"
				end
				return unlink(path)
			end
		]],
		{ failed_link, repairable_link }
	)

	repair(site, plugin)

	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { failed_link }), "/read-only/hcl")
	eq(child.lua_get([[vim.uv.fs_readlink(...)]], { repairable_link }), repairable_target)
	eq(notifications(), {
		{
			msg = "Treesitter query link repair failed for " .. failed_link .. ": EACCES: permission denied",
			level = vim.log.levels.WARN,
		},
		{ msg = "Repaired Treesitter query links: go", level = vim.log.levels.INFO },
	})
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
