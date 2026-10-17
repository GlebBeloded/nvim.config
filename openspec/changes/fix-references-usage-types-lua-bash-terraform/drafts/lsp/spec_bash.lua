local dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local D = "deploy.sh"
local L = "lib.sh"
return {
  name = "bashls",
  cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/bash-language-server"), "start" },
  root = dir .. "/bash",
  filetype = "sh",
  open = { D, L },
  settings = { bashIde = { globPattern = "**/*@(.sh|.inc|.bash|.command)" } },
  wait = 15000,
  queries = {
    { label = "8 region def", file = D, line = 4, find = "region", highlight = true },
    { label = "8b region in ${region:-..}", file = D, line = 18, find = "region:-" },
    { label = "8c region in export", file = D, line = 6, find = "region" },
    { label = "9 count local", file = D, line = 12, find = "count" },
    { label = "9b count in (( count++ ))", file = D, line = 21, find = "count" },
    { label = "10 greet call deploy.sh", file = D, line = 14, find = "greet", highlight = true },
    { label = "10b greet def lib.sh", file = L, line = 1, find = "greet" },
    { label = "11a source ./lib.sh path", file = D, line = 1, find = "lib.sh" },
    { label = "11b . ./lib.sh path", file = D, line = 2, find = "lib.sh" },
    { label = "11c `source` word", file = D, line = 1, find = "source" },
    { label = "12 hosts declare", file = D, line = 7, find = "hosts" },
    { label = "12b hosts in ${hosts[@]}", file = D, line = 13, find = "hosts" },
    { label = "x deploy fn", file = D, line = 10, find = "deploy" },
    { label = "x target local", file = D, line = 11, find = "target" },
  },
}
