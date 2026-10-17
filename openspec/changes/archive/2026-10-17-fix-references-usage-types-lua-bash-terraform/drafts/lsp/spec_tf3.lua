local s = dofile(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/spec_tf2.lua")
s.queries = { { label = "tags", file = "main.tf", line = 4, find = "tags" }, { label = "tags again", file = "main.tf", line = 4, find = "tags" } }
return s
