---@class gleb.language.Disabled
---@field disabled string

---@class gleb.Language
---@field name string
---@field filetypes string[]
---@field lsp gleb.language.Lsp|gleb.language.Disabled
---@field treesitter gleb.language.Treesitter|gleb.language.Disabled
---@field references gleb.language.References|gleb.language.Disabled

---@class gleb.language.Lsp
---@field servers string[]
---@field config? vim.lsp.Config
---@field mason string[]
---@field null_ls? fun(null_ls: table): table[]

---@class gleb.language.Treesitter
---@field parsers string[]

---@class gleb.language.References
---@field test_patterns string[]
---@field usage_types true|gleb.language.Disabled
---@field write_access "documentHighlight"|"tsserver"|false
---@field target_kinds table<string, gleb.references.TargetKind>
---@field fixture { project: string, symbol: string }

---@alias gleb.languages.FacetValidator fun(config: table, language: gleb.Language): error_message: string?

---@class gleb.languages.Facet
---@field language gleb.Language
---@field config table

---@class gleb.Languages
---@field register_facet fun(name: string, validate: gleb.languages.FacetValidator)
---@field facet fun(name: string): gleb.languages.Facet[]
