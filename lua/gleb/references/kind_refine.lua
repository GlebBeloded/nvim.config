local M = {}

local TYPE_POSITION_KINDS = {
	field_declaration = true,
	parameter_declaration = true,
	return_type = true,
	receiver = true,
	variable_declaration = true,
	const_declaration = true,
	type_alias = true,
	type_assertion = true,
	type_conversion = true,
	type_instantiation = true,
	type_constraint = true,
	type_parameter_declaration = true,
	cast = true,
	instanceof = true,
	extends = true,
	impl = true,
	catch = true,
}

---@param kind string
---@param target gleb.references.TargetKind
---@param filetype string
---@return string?
function M.refine_query_kind(kind, target, filetype)
	if kind == "call" and target == "type" and filetype == "go" then
		return "type_conversion"
	end
	local drops_function_argument = kind == "function_argument" and target ~= "function"
	local drops_static_member = kind == "static_member" and target ~= "type"
	local drops_type_position = target ~= "unknown" and target ~= "type" and TYPE_POSITION_KINDS[kind]
	if drops_function_argument or drops_static_member or drops_type_position then
		return nil
	end
	return kind
end

return M
