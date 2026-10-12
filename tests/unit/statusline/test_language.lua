local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare({ "nvim-web-devicons" })
	child.lua([[Language = require("gleb.statusline.language")]])
end

---@return string
local function component()
	return child.lua_get("Language.component()")
end

--- Attach a fake running LSP client (in-process server) to the current buffer.
local function attach_fake_client()
	child.lua([[
		local function server()
			return {
				request = function(method, _, callback)
					callback(nil, method == "initialize" and { capabilities = {} } or {})
					return true, 1
				end,
				notify = function() return true end,
				is_closing = function() return false end,
				terminate = function() end,
			}
		end
		vim.lsp.start({ name = "fake", cmd = server, root_dir = vim.fn.getcwd() })
		vim.wait(1000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end)
	]])
end

local T = H.child_set(child, start)

T["statusline: chip empty without filetype"] = function()
	child.bo.filetype = ""

	eq(component(), "")
end

T["statusline: chip shows error cap without LSP"] = function()
	child.bo.filetype = "lua"
	local chip = component()

	eq(vim.startswith(chip, "%#StatuslineLangCapError#"), true)
	eq(chip:find("lua", 1, true) ~= nil, true)
	eq(chip:match("%%#StatuslineLangEdge#[^%%]*$") ~= nil, true)
end

T["statusline: chip shows ok cap with running LSP"] = function()
	child.bo.filetype = "lua"
	attach_fake_client()

	eq(vim.startswith(component(), "%#StatuslineLangCapOk#"), true)
end

T["statusline: chip logo highlight per filetype"] = function()
	child.bo.filetype = "lua"
	component()

	local chip_bg = child.lua_get([[require("gleb.statusline.palette").chip_bg]])
	local hl_bg = child.lua_get([[vim.api.nvim_get_hl(0, { name = "StatuslineLang_lua" }).bg]])
	eq(string.format("#%06x", hl_bg), chip_bg:lower())
end

T["statusline: chip logo highlight name sanitized"] = function()
	child.bo.filetype = "foo-bar.baz"
	component()

	local chip_bg = child.lua_get([[require("gleb.statusline.palette").chip_bg]])
	local hl_bg = child.lua_get([[vim.api.nvim_get_hl(0, { name = "StatuslineLang_foo_bar_baz" }).bg]])
	eq(string.format("#%06x", hl_bg), chip_bg:lower())
end

T["statusline: chip colorscheme autocmd not duplicated on reload"] = function()
	child.lua([[
        package.loaded["gleb.statusline.language"] = nil
        Language = require("gleb.statusline.language")
    ]])

	local count =
		child.lua_get([[#vim.api.nvim_get_autocmds({ group = "gleb_statusline_language", event = "ColorScheme" })]])
	eq(count, 1)
end

return T
