-- usage: nvim -l dump.lua <lang> <file>
local lang, path = arg[1], arg[2]
local src = table.concat(vim.fn.readfile(path), "\n")
local parser = vim.treesitter.get_string_parser(src, lang)
local root = parser:parse()[1]:root()
print(root:sexpr())
