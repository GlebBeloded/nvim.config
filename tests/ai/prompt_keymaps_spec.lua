local prompt_keymaps = require("gleb.ai.prompt_keymaps")

describe("99 prompt keymaps", function()
	it("submits with Shift+Enter in normal and insert modes", function()
		prompt_keymaps.setup()
		vim.cmd("enew")
		vim.bo.filetype = "99"

		assert.equals("<Cmd>write<CR>", vim.fn.maparg("<S-CR>", "n"))
		assert.equals("<Cmd>write<CR>", vim.fn.maparg("<S-CR>", "i"))
	end)
end)
