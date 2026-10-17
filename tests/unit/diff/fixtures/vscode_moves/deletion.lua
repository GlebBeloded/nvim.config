-- Translated from microsoft/vscode (MIT, © Microsoft Corporation) at 5b23ab39:
-- src/vs/editor/test/node/diffing/fixtures/deletion/advanced.expected.diff.json
-- Modified: JSON rewritten as Lua data, ranges made 0-based.
return {
	lines1 = {
		"import { Link, List, Separator, Stack } from '@fluentui/react';",
		"import { View } from '../../layout/layout';",
		"",
		"export const OtherToolsView = () => {",
		"\treturn (",
		"\t\t<View title='Other Tools'>",
		"\t\t\t<Stack grow={true} verticalFill={true}>",
		"\t\t\t\t<Stack.Item>",
		"\t\t\t\t\t<List",
		"\t\t\t\t\t\titems={[",
		"\t\t\t\t\t\t\t{ name: 'VS Code Standup (Redomond)', href: 'https://vscode-standup.azurewebsites.net' },",
		"\t\t\t\t\t\t\t{ name: 'VS Code Standup (Zurich)', href: 'http://stand.azurewebsites.net/' },",
		"\t\t\t\t\t\t\t{},",
		"\t\t\t\t\t\t\t{ name: 'VS Code Errors', href: 'https://vscode-errors.azurewebsites.net' },",
		"\t\t\t\t\t\t\t{ name: 'VS Code GDPR', href: 'https://github.com/microsoft/vscode-gdpr-tooling' },",
		"\t\t\t\t\t\t]}",
		"\t\t\t\t\t\tonRenderCell={(item) => {",
		"\t\t\t\t\t\t\tif (!item?.name) {",
		"\t\t\t\t\t\t\t\treturn <Separator></Separator>",
		"\t\t\t\t\t\t\t}",
		"\t\t\t\t\t\t\treturn <div style={{ marginBottom: 12 }}><Link href={item!.href} target='_blank'>{item!.name}</Link></div>",
		"\t\t\t\t\t\t}}",
		"\t\t\t\t\t>",
		"\t\t\t\t\t</List>",
		"\t\t\t\t</Stack.Item>",
		"\t\t\t</Stack>",
		"\t\t</View>",
		"\t);",
		"}",
	},
	lines2 = {
		"",
	},
	trim_ws = false,
	changes = {
		{ 0, 29, 0, 1 },
	},
	moves = {},
}
