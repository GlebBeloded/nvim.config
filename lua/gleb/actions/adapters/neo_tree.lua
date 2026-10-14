local adapters = require("gleb.actions.adapters")

return adapters.by_lhs({ "file_tree", "neo_tree" }, adapters.callback)
