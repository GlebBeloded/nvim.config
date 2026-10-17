-- Reference screenshots of Find Usages at its wide and narrow breakpoints.
local F = require("tests.fixtures")
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality
local TIMEOUT_MS = H.lsp_timeout(10000)

local root
local manifest

local LEGEND = {
	b = "PickerBorder",
	t = "MiniPickBorderText",
	f = "MiniPickNormal",
	c = "MiniPickMatchCurrent",
	s = "PickerSecondary",
	r = "CursorLineNr",
	h = "Search",
	x = "PickerHint",
	o = "PickerToggleOn",
	k = "@keyword",
	T = "@type.builtin",
	F = "@function.call",
	m = "@comment",
	n = "@number",
	i = "@punctuation.delimiter",
	j = "@operator",
	q = "@variable.member",
	v = "@type",
	H = "@function",
	J = "@property",
	M = "@module.go",
	V = "@variable.go",
	B = "@punctuation.bracket.go",
	P = "ReferencesProduction",
	p = "ReferencesProductionLabel",
	E = "ReferencesTest",
	e = "ReferencesTestLabel",
	D = "ReferencesFolder",
	d = "ReferencesFolderLabel",
	G = "DevIconGo",
	g = "ReferencesFileLabelDevIconGo",
	C = "ReferencesUsageTypeCall",
	a = "ReferencesUsageTypeCallLabel",
	W = "ReferencesUsageTypeWrite",
	w = "ReferencesUsageTypeWriteLabel",
	Y = "ReferencesUsageTypeRead",
	y = "ReferencesUsageTypeReadLabel",
	z = "ReferencesMaskBackground",
}

local TYPESCRIPT_LEGEND = vim.tbl_extend("force", LEGEND, {
	["."] = "Normal",
	G = "DevIconTypeScript",
	g = "ReferencesFileLabelDevIconTypeScript",
	I = "ReferencesUsageTypeFieldDeclaration",
	i = "ReferencesUsageTypeFieldDeclarationLabel",
	A = "ReferencesUsageTypeImport",
	a = "ReferencesUsageTypeImportLabel",
	W = "ReferencesUsageTypeNew",
	w = "ReferencesUsageTypeNewLabel",
	J = "ReferencesUsageTypeParameterDeclaration",
	j = "ReferencesUsageTypeParameterDeclarationLabel",
	U = "ReferencesUsageTypeReturnType",
	u = "ReferencesUsageTypeReturnTypeLabel",
	Y = "ReferencesUsageTypeStaticMember",
	y = "ReferencesUsageTypeStaticMemberLabel",
	V = "ReferencesUsageTypeExtends",
	v = "ReferencesUsageTypeExtendsLabel",
	L = "ReferencesUsageTypeCast",
	l = "ReferencesUsageTypeCastLabel",
	K = "ReferencesUsageTypeInstanceof",
	["1"] = "ReferencesUsageTypeInstanceofLabel",
	H = "ReferencesUsageTypeTypeInstantiation",
	["2"] = "ReferencesUsageTypeTypeInstantiationLabel",
	R = "ReferencesUsageTypeVariableDeclaration",
	["3"] = "ReferencesUsageTypeVariableDeclarationLabel",
})

local PYTHON_LEGEND = vim.tbl_extend("force", LEGEND, {
	["."] = "Normal",
	["4"] = "ReferencesMaskBackground",
	G = "DevIconPy",
	g = "ReferencesFileLabelDevIconPy",
	I = "ReferencesUsageTypeImport",
	i = "ReferencesUsageTypeImportLabel",
	Z = "ReferencesUsageTypeNew",
	z = "ReferencesUsageTypeNewLabel",
	J = "ReferencesUsageTypeParameterDeclaration",
	j = "ReferencesUsageTypeParameterDeclarationLabel",
	U = "ReferencesUsageTypeExtends",
	u = "ReferencesUsageTypeExtendsLabel",
	V = "ReferencesUsageTypeInstanceof",
	v = "ReferencesUsageTypeInstanceofLabel",
})

local PYTHON_GROUPED_MASK = {
	"......................................................................",
	".........btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	".........bfffPfppppppppppffsfffffffffffffffffffffffffffffffb..........",
	".........bfffffIfiiiiiiffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........",
	".........bcccccccccGcggggggggggccccccccccccccccccccccccccccb..........",
	".........bfffffZfzzzzzzzzzzzzzzzzzzzzzffsffffffffffffffffffb..........",
	".........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........",
	".........bfffffJfjjjjjjjjjjjjjjjjjjjjjffsffffffffffffffffffb..........",
	".........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggggsssfffffffffffffffffffffffffb..........",
	".........bfffffUfuuuuuuuuuffsffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfddddffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggggssffffffffffffffffffffffffffb..........",
	".........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........",
	".........bfffffVfvvvvvvvvvvffsfffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddddffsffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggggggggssfffffffffffffffffffffb..........",
	".........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	".........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........",
	".........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	"......................................................................",
	"......................................................................",
}

local TYPESCRIPT_GROUPED_MASK = {
	"......................................................................",
	".........bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	".........bfffPfppppppppppffssffffffffffffffffffffffffffffffb..........",
	".........bfffffIfiiiiiiiiiiiiiiiiiffsffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bcccccccccGcgggggggggcccccccccccccccccccccccccccccb..........",
	".........bfffffAfaaaaaaffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........",
	".........bfffffWfwwwwwwwwwwwwwwwwwwwwwffsffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........",
	".........bfffffJfjjjjjjjjjjjjjjjjjjjjjffsffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........",
	".........bfffffUfuuuuuuuuuuuffsffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........",
	".........bfffffYfyyyyyyyyyyyyyyyyyyyyffsfffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........",
	".........bfffffVfvvvvvvvvvffsffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggssfffffffffffffffffffffffffffb..........",
	".........bfffffLflllllllllffsffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........",
	".........bfffffKf1111111111ffsfffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........",
	".........bfffffffffGfggggggggsssfffffffffffffffffffffffffffb..........",
	".........bfffffRf33333333333333333333ffsfffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggsssffffffffffffffffffffffffffb..........",
	".........bfffEfeeeeffsfffffffffffffffffffffffffffffffffffffb..........",
	".........bfffffAfaaaaaaffsfffffffffffffffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........",
	".........bfffffYfyyyyyyyyyyyyyyyyyyyyffsfffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........",
	".........bfffffHf222222222222222222ffsfffffffffffffffffffffb..........",
	".........bfffffffDfdddffsffffffffffffffffffffffffffffffffffb..........",
	".........bfffffffffGfgggggggggggggssfffffffffffffffffffffffb..........",
	".........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	".........bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxb..........",
	".........bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..........",
	"......................................................................",
	"......................................................................",
}

local KIND_GROUPED_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBbVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDDDDDDDDDDDDDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVHVwwwwwwwwwwwVVDVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbcVVVVVVVVGVccccccccDDVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVVbBB",
	"BBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjVVVVVVVFFFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVEVeeeeeeeeeeVVDVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVbBB",
	"BBbVVVVVVVVVGVgggggggggggggDDVVVVVVVVVVVVVVVVbVDDDVVjjjjVHHHHHBBVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVgggggggggggggDDVVVVVVVVVVVVVVVVbVrrrVVVVVVVVVVVjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVHVwwwwwwwwwwwVVDVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVgggggggggggggDDVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDFDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local KIND_TAGGED_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBbVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDDDDDDDDDDDDDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbcVVVVVVGVccccccccDDVVVVVVVVVVVVVVVHVcccccVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVVbBB",
	"BBbVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjVVVVVVVFFFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVgggggggggggggDDVVVVVVVVVVHVwwwwwVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVgggggggggggggDDVVVVVVVVVVVEVeeeeVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVbBB",
	"BBbVVVVVVVGVgggggggggggggDDVVVVVVVVVVVEVeeeeVbVDDDVVjjjjVHHHHHBBVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVrrrVVVVVVVVVVVjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local WIDE_DEFAULT_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBbVVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDDDDDDDDDDDDDDDDDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVVVVVVVVVjjjjjjVBVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbcVVVVVVVVGVccccccccccDDDVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVBBFFFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggggDDDVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggggDDVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVbBB",
	"BBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVBBVFFFFFFFBVHHHBBVFFFFFFVBVVVVVVVVVVVVVVbBB",
	"BBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVjjVCVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVddddddddddddddVVDVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjVVEVVVVVVVjjVjjjjjVVEJJJJJVBVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVgggggggggggggDDVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVrrrVVVVVVjjjjjjVVVVVVEHHHHHHBVVVVVBVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVBBVFFFFFFFBVHHHHHHHHBBVBBFFFFFFVBVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVjjVBBFFFFFFBBVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjVVEVVVVVVVjjVjjjjjVVEJJJJJVBVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVjVHHHHHHBVVVVVEVVVVVVEHHHHHHBVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjjjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDFDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local NARROW_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbBBBBBBBBBB",
	"BBBBBBBBBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbcVVVVVVVVGVccccccccccDDDVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVVVGVggggggggggDDDVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVDVddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVVVGVggggggggggDDVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVDVddddddddddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbVVVVVVVVVGVgggggggggggggDDVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB",
	"BBBBBBBBBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBBBBBBBBBB",
	"BBBBBBBBBbVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDFDDDDDDDDDDDDDDbBBBBBBBBBB",
	"BBBBBBBBBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local STRUCT_GROUPED_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDDDDDDDDDDDDDDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVJVpppppppppppppppppVVDVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbcVVVVVVVVGVccccccccDDVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"BBbVVVVVVVVVGVggggggggDDVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVVVVVVVjjjjjjVBVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVJVpppppppppppppppppppppVVDVVVVVVVVVVVbVrrrVVVVVVVVVVVVVVFFFFFFFVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVBBjFFFFFFFVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVJVppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"BBbVVVVVVVVVGVggggggggggDDDVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVHHHHHHHHHHBBBBBBVFFFBVjFFFFFFFVBVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggggDDDVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjjjjVjFFFFFFFBVVVVVEVBBFFFBVVVVVBBVVVVVbBB",
	"BBbVVVVVJVpppppppppppVVDVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVHHHHHBBBBVFFFFFFFEVBBBBBVBBFFFBVFFFFFFFVbBB",
	"BBbVVVVVCVaaaaaaaaaaaaaaaaaaaaaVVDVVVVVVVVVVVbVDDDVVVVVVVVVEJJJJJVjVHHHHHHBVVVEJJJJJEVVVVVVjjjBVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjjjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVCVaaaaaaaaaaaaaaaaaaaaaVVDVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVGVgggggggggggggggDDVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDFDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local STRUCT_TAGGED_MASK = {
	"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVJVppppppppppVVDVVVVVVVVVVVVVVVVVVVVVVVVbVDDDDDDDDDDDDDDDDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbcVVVVVVGVccccccccDDVVVVVVVVVVVVVVVJVcccccVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggDDVVVVVVVVVVVVVVVJVpppppVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"BBbVVVVVVVGVggggggggDDDVVVVVVVVVVVVVJVppppppVbVDDDVVjjjjVVVVVVVjjjjjjVBVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVVCVaaaaVbVrrrVVVVVVVVVVVVVVFFFFFFFVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggDDDVVVVVVVVVVVVVVJVpppppVbVDDDVVVVVVVVVVVVVVBBjFFFFFFFVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggDDDVVVVVVVVVVVVVJVppppppVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggggDDDVVVVVVVVVJVppppppppVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVGVggggggggggDDDVVVVVVVVVJVppppppppVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"BBbVVVEVeeeeVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVHHHHHHHHHHBBBBBBVFFFBVjFFFFFFFVBVVVVVVVVbBB",
	"BBbVVVVVDVdddddddVVDVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjjjjVjFFFFFFFBVVVVVEVBBFFFBVVVVVBBVVVVVbBB",
	"BBbVVVVVVVGVgggggggggggggggDDVVVVVVVVVCVaaaaVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjVHHHHHBBBBVFFFFFFFEVBBBBBVBBFFFBVFFFFFFFVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVVVVEJJJJJVjVHHHHHHBVVVEJJJJJEVVVVVVjjjBVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVVVVVjjjjjjVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBbVVVVVVVVVVVVVVVVVVVVVVVVVDDDDDDDDDDDDDDDDDDDFDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDbBB",
	"BBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBB",
	"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
}

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
end

local T = H.child_set(child, start)

---@param columns integer
---@param lines integer
local function open_format(columns, lines)
	child.o.columns, child.o.lines = columns, lines
	local call = vim.iter(manifest.references.Format):find(function(location)
		return location.path == "billing/invoice.go" and location.line == 16
	end)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(call.path))
	child.api.nvim_win_set_cursor(0, { call.line, call.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function open_calls()
	child.o.columns, child.o.lines = 100, 30
	local declaration = manifest.references.Calls[1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function open_invoice()
	child.o.columns, child.o.lines = 100, 30
	local declaration = manifest.references.Invoice[1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function open_money()
	child.o.columns, child.o.lines = 70, 50
	local typescript_root, typescript_manifest = F.copy("tsproj", vim.fn.tempname())
	local declaration = typescript_manifest.references.Money[1]
	child.cmd("cd " .. vim.fn.fnameescape(typescript_root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.wo.number = true
	child.wo.relativenumber = false
	child.wo.numberwidth = 3
	child.lua([[require("ibl").setup_buffer(0, { enabled = false })]])
	child.o.showtabline = 0
	child.o.laststatus = 2
	child.wo.winbar = "%#Normal#▎ money.ts"
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "vtsls" }) > 0]], TIMEOUT_MS), true)
	child.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "vtsls" })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }
	client:request("textDocument/references", params, function(_, result)
		populated = result and #result >= minimum and populated + 1 or 0
		if populated >= 2 then
			_G.references_ready = true
		elseif (vim.uv.hrtime() - started) / 1e6 < timeout then
			vim.defer_fn(request, 10)
		end
	end, bufnr)
end
request()
]],
		{ #typescript_manifest.references.Money - 1, TIMEOUT_MS }
	)
	eq(child.wait("_G.references_ready == true", TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.lua([[
local state = require("gleb.references.view").state
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=typescript "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=typescript "
]])
	child.cmd("redraw")
end

local function open_python_money()
	child.o.columns, child.o.lines = 70, 24
	local python_root, python_manifest = F.copy("pyproj", vim.fn.tempname())
	local declaration = python_manifest.references.Money[1]
	child.cmd("cd " .. vim.fn.fnameescape(python_root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.wo.number = true
	child.wo.relativenumber = false
	child.wo.numberwidth = 3
	child.lua([[require("ibl").setup_buffer(0, { enabled = false })]])
	child.o.showtabline = 0
	child.o.laststatus = 2
	child.wo.winbar = "%#Normal#▎ money.py"
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "basedpyright" }) > 0]], TIMEOUT_MS), true)
	child.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "basedpyright" })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }
	client:request("textDocument/references", params, function(_, result)
		populated = result and #result >= minimum and populated + 1 or 0
		if populated >= 2 then
			_G.references_ready = true
		elseif (vim.uv.hrtime() - started) / 1e6 < timeout then
			vim.defer_fn(request, 10)
		end
	end, bufnr)
end
request()
]],
		{ #python_manifest.references.Money - 1, TIMEOUT_MS }
	)
	eq(child.wait("_G.references_ready == true", TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.lua([[
local state = require("gleb.references.view").state
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=python "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=python "
]])
	child.cmd("redraw")
end

local function tree_lines()
	return child.lua_get([[vim.api.nvim_buf_get_lines(require("gleb.references.view").state.tree_buf, 0, -1, false)]])
end

local function hint_line()
	return child.lua_get(
		[=[vim.api.nvim_buf_get_lines(require("gleb.references.view").state.hint_buf, 0, 1, false)[1]]=]
	)
end

-- Design masks intentionally leave the editor outside the view uncoloured. Clear
-- that background after the text screenshot so only view-owned colours are checked.
local function clear_background_for_mask()
	child.lua([[
local view = require("gleb.references.view")
local win = view.state.origin_win
local buf = vim.api.nvim_win_get_buf(win)
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
vim.wo[win].number = false
vim.wo[win].relativenumber = false
vim.wo[win].signcolumn = "no"
vim.wo[win].winhighlight = "EndOfBuffer:Normal,LineNr:Normal,SignColumn:Normal"
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
vim.api.nvim_set_hl(0, "NormalNC", normal)
vim.api.nvim_set_hl(0, "NormalFloat", normal)
vim.api.nvim_set_hl(0, "EndOfBuffer", normal)
vim.api.nvim_set_hl(0, "NonText", normal)
local palette = require("gleb.colors.gruvbox-material.palette")
vim.api.nvim_set_hl(0, "ReferencesMaskBackground", {
	fg = palette.foreground.fg0,
	bg = palette.background.bg0,
})
vim.o.showtabline = 0
vim.o.laststatus = 0
vim.cmd("redraw!")
]])
end

---@param mask string[]
---@return string[]
local function with_cleared_background(mask)
	local result = vim.deepcopy(mask)
	for index = 2, #result do
		result[index] = result[index]:gsub("%.", "z")
	end
	return result
end

---@param mask string[]
---@return string[]
local function with_cleared_typescript_background(mask)
	local result = vim.deepcopy(mask)
	result[1] = result[1]:gsub("%.", "z")
	for index = 3, #result do
		result[index] = result[index]:gsub("%.", "z")
	end
	return result
end

---@param mask string[]
---@return string[]
local function with_cleared_python_background(mask)
	local result = vim.deepcopy(mask)
	result[1] = result[1]:gsub("%.", "4")
	for index = 3, #result do
		result[index] = result[index]:gsub("%.", "4")
	end
	return result
end

T["references: Wide view matches reference screenshot"] = function()
	open_format(100, 30)
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(WIDE_DEFAULT_MASK), LEGEND)
end

T["references: Tests key cycles grouped, hidden and mixed"] = function()
	open_format(100, 30)
	local default = child.get_screenshot()
	child.type_keys("t")
	eq(child.lua_get([[require("gleb.references.view").state.tree.count]]), 3)
	eq(hint_line():find("Tests: hidden t", 1, true) ~= nil, true)
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("t")
	eq(
		child.lua_get([[(function()
		local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		return {
			text:find("Production", 1, true) == nil,
			text:find("Test  ", 1, true) == nil,
			text:find("money_test.go:6", 1, true) ~= nil,
			text:find(" test", 1, true) ~= nil,
		}
	end)()]]),
		{ true, true, true, true }
	)
	eq(tree_lines()[1], "▾  Call  4")
	eq(hint_line():find("Tests: mixed t", 1, true) ~= nil, true)
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("t")
	child.cmd("redraw")
	eq(child.get_screenshot(), default)
end

T["references: Mixed tests without folders is a flat list"] = function()
	open_format(100, 30)
	child.type_keys("ttf")
	eq(tree_lines(), {
		"▾  Call  4",
		"   billing/invoice.go:16",
		"   billing/invoice.go:23",
		"   …ternal/money/money_test.go:6  test",
		"   report/summary.go:7",
	})
	eq(hint_line():find("Tests: mixed t · ○ Folders f", 1, true) ~= nil, true)
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
end

T["references: Narrow view fits its content"] = function()
	open_format(70, 24)
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(NARROW_MASK), LEGEND)
end

local grouped_scenario = "references: Variable usages are grouped by write and read"
T[grouped_scenario] = MiniTest.new_set()
T[grouped_scenario]["matches approved K1"] = function()
	open_calls()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(KIND_GROUPED_MASK), LEGEND)
end

local tagged_scenario = "references: u turns the level into row tags"
T[tagged_scenario] = MiniTest.new_set()
T[tagged_scenario]["matches approved K2 through the real key"] = function()
	open_calls()
	child.type_keys("u")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(KIND_TAGGED_MASK), LEGEND)
end

T["references: Struct usages are grouped by usage type"] = function()
	open_invoice()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(STRUCT_GROUPED_MASK), LEGEND)
end

T["references: u turns struct usage types into row tags"] = function()
	open_invoice()
	child.type_keys("u")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(STRUCT_TAGGED_MASK), LEGEND)
end

T["references: TypeScript class usages are grouped by usage type"] = function()
	eq(require("tests.render.cases").ts_p1_class ~= nil, true)
	open_money()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_typescript_background(TYPESCRIPT_GROUPED_MASK), TYPESCRIPT_LEGEND)
end

T["references: Python class usages are grouped by usage type"] = function()
	eq(require("tests.render.cases").py_p1_class ~= nil, true)
	open_python_money()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_python_background(PYTHON_GROUPED_MASK), PYTHON_LEGEND)
end

return T
