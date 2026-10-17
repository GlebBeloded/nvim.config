local P = {}

P.key = "price"

function P.of(item)
	return item.price or 0
end

return P
