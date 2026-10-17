-- Owned two-side diff viewer initialization.

require("gleb.diff.view.highlights")
local view = require("gleb.diff.view")
local settings = require("gleb.diff.settings").load()
view.config.policy = settings.policy
view.config.highlight = settings.highlight
