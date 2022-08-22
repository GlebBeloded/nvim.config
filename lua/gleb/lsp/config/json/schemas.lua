local schemas = {
	{
		description = "TypeScript compiler configuration file",
		fileMatch = {
			"tsconfig.json",
			"tsconfig.*.json",
		},
		url = "https://json.schemastore.org/tsconfig.json",
	},
	{
		description = "Babel configuration",
		fileMatch = {
			".babelrc.json",
			".babelrc",
			"babel.config.json",
		},
		url = "https://json.schemastore.org/babelrc.json",
	},
	{
		description = "ESLint config",
		fileMatch = {
			".eslintrc.json",
			".eslintrc",
		},
		url = "https://json.schemastore.org/eslintrc.json",
	},
	{
		description = "Prettier config",
		fileMatch = {
			".prettierrc",
			".prettierrc.json",
			"prettier.config.json",
		},
		url = "https://json.schemastore.org/prettierrc",
	},
	{
		description = "Stylelint config",
		fileMatch = {
			".stylelintrc",
			".stylelintrc.json",
			"stylelint.config.json",
		},
		url = "https://json.schemastore.org/stylelintrc",
	},
	{
		description = "Schema for CMake Presets",
		fileMatch = {
			"CMakePresets.json",
			"CMakeUserPresets.json",
		},
		url = "https://raw.githubusercontent.com/Kitware/CMake/master/Help/manual/presets/schema.json",
	},
	{
		description = "Configuration file as an alternative for configuring your repository in the settings page.",
		fileMatch = {
			".codeclimate.json",
		},
		url = "https://json.schemastore.org/codeclimate.json",
	},
	{
		description = "LLVM compilation database",
		fileMatch = {
			"compile_commands.json",
		},
		url = "https://json.schemastore.org/compile-commands.json",
	},
	{
		description = "Config file for Command Task Runner",
		fileMatch = {
			"commands.json",
		},
		url = "https://json.schemastore.org/commands.json",
	},
	{
		description = "Json schema for properties json file for a GitHub Workflow template",
		fileMatch = {
			".github/workflow-templates/**.properties.json",
		},
		url = "https://json.schemastore.org/github-workflow-template-properties.json",
	},
	{
		description = "golangci-lint configuration file",
		fileMatch = {
			".golangci.toml",
			".golangci.json",
		},
		url = "https://json.schemastore.org/golangci-lint.json",
	},
	{
		description = "JSON schema for the JSON Feed format",
		fileMatch = {
			"feed.json",
		},
		url = "https://json.schemastore.org/feed.json",
		versions = {
			["1"] = "https://json.schemastore.org/feed-1.json",
			["1.1"] = "https://json.schemastore.org/feed.json",
		},
	},
	{
		description = "Packer template JSON configuration",
		fileMatch = {
			"packer.json",
		},
		url = "https://json.schemastore.org/packer.json",
	},
	{
		description = "NPM configuration file",
		fileMatch = {
			"package.json",
		},
		url = "https://json.schemastore.org/package.json",
	},
	{
		description = "Resume json",
		fileMatch = { "resume.json" },
		url = "https://raw.githubusercontent.com/jsonresume/resume-schema/v1.0.0/schema.json",
	},
}

return schemas
