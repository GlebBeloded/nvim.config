local price = require("shop.price")
local M, KEY, log, emit, report_count = {}, nil, function(_) end, function(_) end, nil

---@param items table[]
function M.total(items)
	local sum = 0
	for _, item in ipairs(items) do
		sum = sum + price.of(item)
	end
	return sum
end

function M:apply(discount)
	self.discount = discount
	return M.total(self.items) * (1 - discount)
end

M.format = function(value)
	return string.format("%.2f", value)
end

local defaults = {
	total = 0,
	format = function(v)
		return tostring(v)
	end,
	[price.key] = true,
	[KEY] = false,
}

local function report(cart)
	print(M.format(M.total(cart.items)))
	log("report " .. defaults.total)
	emit({ total = cart.total })
	cart:apply(0.1)
	M.notify("done")
	M.render({ cart })
end

M.cache, report_count = nil, 1
local handler = function() end
local first, second
return M, report, handler, first, second, report_count, KEY, log, emit
