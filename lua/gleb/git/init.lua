require("gleb.git.blame")
require("gleb.git.gitsigns")

vim.api.nvim_create_user_command("Blame", ":GitBlameToggle", {})
