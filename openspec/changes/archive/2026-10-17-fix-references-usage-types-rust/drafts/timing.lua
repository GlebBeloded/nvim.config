for _, lang in ipairs({ "rust" }) do
  local t = vim.uv.hrtime()
  local q = vim.treesitter.query.get(lang, "usages")
  local file = _G.arg[1] .. "/fixtures/usages." .. "rs"
  local src = table.concat(vim.fn.readfile(file), "\n"):rep(50, "\n")
  local t2 = vim.uv.hrtime()
  local root = vim.treesitter.get_string_parser(src, lang):parse()[1]:root()
  local n = 0
  for _ in q:iter_matches(root, src) do n = n + 1 end
  print(lang, ("compile %.1fms, full-file matches on %d lines: %d in %.1fms, patterns=%d"):format((t2 - t) / 1e6,
    select(2, src:gsub("\n", "")), n, (vim.uv.hrtime() - t2) / 1e6, #q.info.patterns))
end
