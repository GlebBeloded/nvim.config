-- In init.lua or filetype.nvim's config file
require("filetype").setup({
    overrides = {
        extensions = {
            -- Set the filetype of *.pn files to potion
            mod = "gomod",
            sum = "gomod",
        },
        complex = {
            -- Set the filetype of any full filename matching the regex to gitconfig
            [".*git/config"] = "gitconfig", -- Included in the plugin
        },

        shebang = {
            -- Set the filetype of files with a dash shebang to sh
            dash = "sh",
        },
    },
})
