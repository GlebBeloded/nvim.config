## MODIFIED Requirements

### Requirement: Statusline visual style
The config SHALL color the statusline from `gleb.statusline.palette` (derived from the gruvbox-material palette: bar = `bg0` blended 5% toward orange and brightened 2%; mode accents normal=green, insert=blue, visual=purple, replace=red, command=yellow, terminal=aqua; section a text in `bg0`, bold; inactive text in `bg5`) and render the language chip as a rounded pill with `chip_bg` background.

#### Scenario: statusline matches reference screenshot
- **WHEN** a Lua file is open in Normal mode with gruvbox-material active, no LSP client attached to its buffer, and `MiniTest` child `expect.reference_screen()` is taken of the statusline row
- **THEN** it matches the stored reference screenshot, including mode accent, bar color and language chip, and in an 80-column statusline the chip takes columns 72–80 with the left cap in `StatuslineLangCapError` and the right cap in `StatuslineLangEdge`

#### Scenario: insert mode accent matches reference screenshot
- **WHEN** `i` is pressed in Normal mode, no LSP client is attached to the buffer, and a screenshot of the statusline row is taken
- **THEN** it matches the stored reference screenshot with the insert (blue) accent on the mode section, and the chip takes columns 72–80 with the left cap in `StatuslineLangCapError` and the right cap in `StatuslineLangEdge`
