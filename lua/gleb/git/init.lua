require("gleb.git.blame")

vim.api.nvim_create_user_command("Blame", ":GitBlameToggle", {})
