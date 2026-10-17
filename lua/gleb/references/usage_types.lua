-- Find Usages types keep labels, glyphs and colour families in one language-neutral catalogue.
---@class gleb.references.UsageType
---@field label string
---@field icon string
---@field colour "aqua"|"blue"|"green"|"grey2"|"orange"|"purple"|"yellow"
---@field tag string
---@field order integer

---@type table<string, gleb.references.UsageType>
local M = {
	call = { label = "Call", icon = "", colour = "purple", tag = "call", order = 1 },
	catch = { label = "Catch clause", icon = "󰒙", colour = "aqua", tag = "catch", order = 2 },
	const_declaration = { label = "Const declaration", icon = "", colour = "aqua", tag = "const", order = 3 },
	data_reference = { label = "Data source reference", icon = "󱘲", colour = "aqua", tag = "data", order = 4 },
	decorator = { label = "Decorator", icon = "󰁥", colour = "purple", tag = "decorator", order = 5 },
	depends_on = { label = "Dependency", icon = "󰌹", colour = "orange", tag = "depends", order = 6 },
	export = { label = "Export", icon = "󰈇", colour = "green", tag = "export", order = 7 },
	field_access = { label = "Field access", icon = "", colour = "grey2", tag = "field", order = 8 },
	field_declaration = { label = "Field declaration", icon = "", colour = "aqua", tag = "field", order = 9 },
	field_initialization = { label = "Field initialization", icon = "", colour = "purple", tag = "init", order = 10 },
	function_argument = { label = "Function argument", icon = "󰡱", colour = "purple", tag = "arg", order = 11 },
	function_declaration = { label = "Function declaration", icon = "󰊕", colour = "aqua", tag = "func", order = 12 },
	impl = { label = "Impl", icon = "", colour = "orange", tag = "impl", order = 13 },
	import = { label = "Import", icon = "", colour = "green", tag = "import", order = 14 },
	keyword_argument = { label = "Keyword argument", icon = "", colour = "purple", tag = "kwarg", order = 15 },
	local_reference = { label = "Local value reference", icon = "", colour = "aqua", tag = "local", order = 16 },
	macro_argument = { label = "Macro argument", icon = "󰐣", colour = "purple", tag = "macro arg", order = 17 },
	macro = { label = "Macro call", icon = "󰐣", colour = "purple", tag = "macro", order = 18 },
	attribute_assignment = { label = "Module input", icon = "󰋺", colour = "purple", tag = "input", order = 19 },
	module_reference = { label = "Module reference", icon = "󰆧", colour = "aqua", tag = "module", order = 20 },
	new = { label = "New instance creation", icon = "", colour = "purple", tag = "new", order = 21 },
	output = { label = "Output value", icon = "󰈇", colour = "green", tag = "output", order = 22 },
	parameter_declaration = {
		label = "Parameter declaration",
		icon = "",
		colour = "aqua",
		tag = "param",
		order = 23,
	},
	pattern = { label = "Pattern", icon = "󰠲", colour = "orange", tag = "pattern", order = 24 },
	receiver = { label = "Receiver", icon = "", colour = "aqua", tag = "receiver", order = 25 },
	resource_reference = { label = "Resource reference", icon = "󰅣", colour = "aqua", tag = "resource", order = 26 },
	return_type = { label = "Return type", icon = "󰌑", colour = "aqua", tag = "return", order = 27 },
	static_member = { label = "Static member access", icon = "", colour = "orange", tag = "static", order = 28 },
	struct_initialization = {
		label = "Struct initialization",
		icon = "",
		colour = "purple",
		tag = "init",
		order = 29,
	},
	extends = { label = "Supertype", icon = "", colour = "orange", tag = "supertype", order = 30 },
	type_alias = { label = "Type alias", icon = "", colour = "orange", tag = "alias", order = 31 },
	type_assertion = { label = "Type assertion", icon = "", colour = "orange", tag = "assert", order = 32 },
	cast = { label = "Type cast", icon = "󰓡", colour = "orange", tag = "cast", order = 33 },
	instanceof = { label = "Type check", icon = "", colour = "orange", tag = "check", order = 34 },
	type_constraint = { label = "Type constraint", icon = "", colour = "orange", tag = "constraint", order = 35 },
	type_conversion = { label = "Type conversion", icon = "󰓡", colour = "orange", tag = "convert", order = 36 },
	type_instantiation = {
		label = "Type instantiation",
		icon = "󰅴",
		colour = "orange",
		tag = "type arg",
		order = 37,
	},
	type_parameter_declaration = {
		label = "Type parameter declaration",
		icon = "",
		colour = "orange",
		tag = "type param",
		order = 38,
	},
	unclassified = { label = "Unclassified", icon = "", colour = "grey2", tag = "", order = 39 },
	read = { label = "Value read", icon = "󰈈", colour = "yellow", tag = "read", order = 40 },
	write = { label = "Value write", icon = "󰏫", colour = "blue", tag = "write", order = 41 },
	variable_declaration = { label = "Variable declaration", icon = "", colour = "aqua", tag = "var", order = 42 },
}

return M
