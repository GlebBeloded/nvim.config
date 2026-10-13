## Root cause

neo-tree selects porcelain v2 on the installed Git version. Its parser skips every leading output line
whose record type is not `1`, `2`, `?`, or `!`; porcelain v2 uses `u` for an unmerged record. When a
conflict is the only status entry, the parser reaches end-of-output and reports an empty status. Forcing
neo-tree's supported porcelain version to v1 after setup uses its conflict-aware v1 parser without
forking the plugin. The override stays local to the neo-tree configuration and can be removed when the
upstream v2 parser accepts `u` records.

## Current render

**Current**: `35x5`, excerpt: focused neo-tree `git_status` window, Normal mode, `main`, lone unmerged
`conflict.txt`

```text
  Git Status [main]                 
                                    
  working tree clean                
                                    
                                    
```

The leading porcelain v2 `u` record is discarded, so the tree incorrectly appears clean.

## Proposed render

**Proposed**: `35x5`, excerpt: focused neo-tree `git_status` window, Normal mode, `main`, lone unmerged
`conflict.txt`

```text
  Git Status [main]                 
                                    
   ◆ conflict.txt                  
                                    
                                    
```

The existing conflict symbol is visible for the lone unmerged file. No colors, layout, or mappings
change.
