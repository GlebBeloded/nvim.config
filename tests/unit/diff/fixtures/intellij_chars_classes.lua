-- Translated from intellij-community (Apache-2.0, © JetBrains s.r.o.) at d4223873:
-- platform/diff-impl/tests/testSrc/com/intellij/diff/comparison/TrimUtilTest.kt
-- Modified: Kotlin DSL rewritten as Lua data and UTF-16 offsets as UTF-8 bytes; see lua/gleb/diff/engine/NOTICE.
return {
	punctuation = "(){}[],./?`~!@#$%^&*-=+|\\;:'\"<>",
	alpha = {
		{ text = "!? \t\n+~", expected = false },
		{ text = "AB12", expected = true },
		{ text = "АБВ汉语日ひรไ", expected = true },
		{ text = "óèäñĀ", expected = true },
		{ text = "\r_\x01", expected = true },
		{ text = "😂🧒", expected = true },
	},
	continuous = {
		{ text = "12_ABZ", expected = false },
		{ text = "АБВ", expected = false },
		{ text = "ʁit", expected = false },
		{ text = "음훈", expected = false },
		{ text = "óèäñĀ", expected = false },
		{ text = "\r_\x01", expected = false },
		{ text = "象形文字", expected = true },
		{ text = "อักษรไ", expected = true },
		{ text = "ひらがなカタカナ日本語", expected = true },
		{ text = "汉语漢語", expected = true },
		{ text = "☺♥", expected = true },
		{ text = "😂🧒", expected = true },
		{ text = "‎‏؜", expected = true },
	},
}
