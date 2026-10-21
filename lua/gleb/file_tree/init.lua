local settings = require("gleb.tree.settings")
if not settings.state.path then
	settings.setup({})
end
require("gleb.file_tree.view").setup()
