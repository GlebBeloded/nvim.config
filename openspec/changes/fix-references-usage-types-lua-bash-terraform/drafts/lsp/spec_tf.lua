local dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local R = "main.tf"
local N = "net/main.tf"
return {
  name = "terraformls",
  cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/terraform-ls"), "serve" },
  root = dir .. "/tf",
  filetype = "terraform",
  open = { R, N },
  wait = 30000,
  stable = 3,
  queries = {
    { label = "13 variable \"region\" label", file = R, line = 0, find = "region", highlight = true },
    { label = "13b var.region usage (on region)", file = R, line = 9, find = "region", },
    { label = "13c var.region usage (on var)", file = R, line = 9, find = "var." },
    { label = "13d `variable` keyword", file = R, line = 0, find = "variable" },
    { label = "14 locals name", file = R, line = 9, find = "name" },
    { label = "14b local.name usage", file = R, line = 19, find = "name" },
    { label = "15 module \"net\" label", file = R, line = 13, find = "net" },
    { label = "15b module.net in depends_on", file = R, line = 22, find = "net" },
    { label = "16 output \"vpc_id\" (net)", file = N, line = 4, find = "vpc_id" },
    { label = "16b module.net.vpc_id usage", file = R, line = 31, find = "vpc_id" },
    { label = "17 resource aws_s3_bucket logs (on logs)", file = R, line = 18, find = "logs" },
    { label = "17a resource aws_s3_bucket logs (on type)", file = R, line = 18, find = "aws_s3_bucket" },
    { label = "17b data aws_ami base (on base)", file = R, line = 25, find = "base" },
    { label = "17c data.aws_ami.base.id usage", file = R, line = 30, find = "base" },
    { label = "18 variable cidr (net)", file = N, line = 0, find = "cidr" },
    { label = "18b cidr module input attr (root)", file = R, line = 15, find = "cidr" },
    { label = "x variable tags", file = R, line = 4, find = "tags" },
  },
}
