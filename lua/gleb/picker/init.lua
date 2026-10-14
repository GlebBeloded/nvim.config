local frame = require("gleb.picker.frame")
local actions = require("gleb.picker.actions")

if frame.setup then
	frame.setup()
end

actions.start = frame.start

return actions
