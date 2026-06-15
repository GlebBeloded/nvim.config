# Case Study: Fixing Cmd+Shift+=/- Keybindings for Folding

## Problem

Cmd+Shift+= and Cmd+Shift+- keybindings for fold all/unfold all in Neovim were not working, even though:
- Alacritty was configured to send escape sequences (`\u001B+` and `\u001B_`)
- Neovim had mappings for `<A-+>` and `<A-_>`
- Zellij was not intercepting these keys
- The mappings showed up in `:nmap` output

## Root Cause

**Special characters with Shift modifiers behave differently than letter keys in the Alacritty → Zellij → Neovim chain.**

While letter keys like `Cmd+E` correctly translate to Alt sequences (`<A-e>` in Neovim), special characters like `+` and `-` (which are Shift+= and Shift+- on the keyboard) preserve the full modifier chain.

## Diagnostic Process

### Step 1: Verify the mapping exists
```vim
:verbose nmap <A-+>
```
**Result**: Mapping existed and pointed to the correct function.

### Step 2: Check what Neovim receives
```vim
i<Ctrl-V><Cmd+Shift+=>
```
**Result**: Showed `<S-D-=>` (not `<A-+>` or `<M-+>` as expected)

Where:
- `S` = Shift modifier
- `D` = Command/Super modifier (macOS Command key)
- `=` = Base key

### Step 3: Alternative diagnostic
```vim
i<Ctrl-V><Cmd+Shift+=><Esc>
```
This showed the raw bytes: `<80><fc><82>=` followed by `\27` (ESC)

The `<80><fc><82>` is Neovim's internal byte representation for the modifier combination before it translates to `<S-D-=>`.

## Solution

Use the **exact key notation that Neovim sees**, not what we expect it to see:

```lua
-- lua/gleb/folding/init.lua
vim.keymap.set("n", "<S-D-=>", ufo.openAllFolds, { noremap = true, silent = true })
vim.keymap.set("n", "<S-D-->", ufo.closeAllFolds, { noremap = true, silent = true })
```

## Why This Happens

### For Letter Keys (Working as Expected)
```
Cmd+E → Alacritty sends \u001Be → Neovim sees <A-e> ✓
```

### For Special Characters (Different Behavior)
```
Cmd+Shift+= → Alacritty sends \u001B+ → Neovim sees <S-D-=> (not <A-+>)
Cmd+Shift+- → Alacritty sends \u001B_ → Neovim sees <S-D--> (not <A-_>)
```

**Why the difference?**

When Alacritty sends `\u001B+`:
- It's sending ESC + the literal character `+`
- `+` is already a shifted character (Shift+= on keyboard)
- Neovim, detecting this came with modifiers, reconstructs the full key context
- Instead of interpreting it as just Alt+Plus, Neovim preserves: Shift+Command+Equals

## Configuration Files

### Alacritty (`~/.config/alacritty/keymaps_macos.toml`)
```toml
[[keyboard.bindings]]
chars = "\u001B_"
key = "Minus"
mods = "Command|Shift"

[[keyboard.bindings]]
chars = "\u001B+"
key = "Equals"
mods = "Command|Shift"
```

### Neovim (`~/.config/nvim/lua/gleb/folding/init.lua`)
```lua
-- Use the notation Neovim actually sees, not what we expect
vim.keymap.set("n", "<S-D-=>", ufo.openAllFolds, { noremap = true, silent = true })
vim.keymap.set("n", "<S-D-->", ufo.closeAllFolds, { noremap = true, silent = true })

-- These work fine for single character (non-shifted special chars)
vim.keymap.set("n", "<M-=>", "zo", { noremap = true, silent = true })
vim.keymap.set("n", "<M-->", "zc", { noremap = true, silent = true })
```

## Key Takeaways

1. **Always test what Neovim actually receives** using `i<Ctrl-V><key>` before assuming the key notation
2. **Special characters behave differently** from letter keys in the translation chain
3. **Shifted special characters** (`+`, `_`, `!`, `@`, etc.) may preserve full modifier chains
4. **The `D` modifier** in Neovim key notation represents the Command/Super key on macOS
5. **`<80><fc><82>`** is Neovim's internal byte encoding - you can't map to it directly, but it reveals what modifiers are present

## Debugging Workflow for Future Issues

When a keybinding doesn't work:

1. **Check if mapping exists**: `:verbose nmap <expected-key>`
2. **Test what Neovim sees**: `i<Ctrl-V><actual-key-press>`
3. **Check raw bytes** (optional): Same as step 2, shows internal encoding
4. **Verify Zellij isn't intercepting**: Check `~/.config/zellij/config.kdl` for conflicting bindings
5. **Map to actual notation**: Use the exact notation from step 2 in your keymap
6. **Restart Neovim**: `:source ~/.config/nvim/init.lua` or reopen
7. **Test**: Press the key and verify it works

## Related Issues

This same pattern may affect other shifted special characters:
- `!` (Shift+1)
- `@` (Shift+2)
- `#` (Shift+3)
- `$` (Shift+4)
- `%` (Shift+5)
- `^` (Shift+6)
- `&` (Shift+7)
- `*` (Shift+8)
- `(` (Shift+9)
- `)` (Shift+0)
- `_` (Shift+-)
- `+` (Shift+=)
- `{` (Shift+[)
- `}` (Shift+])
- `|` (Shift+\)
- `:` (Shift+;)
- `"` (Shift+')
- `<` (Shift+,)
- `>` (Shift+.)
- `?` (Shift+/)
- `~` (Shift+`)

If you're mapping `Cmd+Shift+<any-of-these>`, always verify with `Ctrl-V` what Neovim actually receives.

## References

- Main keybinding documentation: `~/.config/nvim/KEYBINDINGS.md`
- Neovim key notation help: `:help key-notation`
- Neovim key codes: `:help keycodes`
