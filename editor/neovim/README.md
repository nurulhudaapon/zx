## Installation

```lua
-- ~/.config/nvim/lua/plugins/zx.lua
return {
    "nurulhudaapon/zx",
    dependencies = { 
        "nvim-treesitter/nvim-treesitter",
        "neovim/nvim-lspconfig",  -- for LSP support
        "nvim-tree/nvim-web-devicons",  -- for file icons
    },
    -- Load on startup for immediate LSP and icon support
    lazy = false,
    priority = 50,
    config = function()
        vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/zx/editor/neovim")
        vim.cmd("runtime! plugin/zx.lua")
    end,
}
```

## Features

### Syntax Highlighting
- Tree-sitter based syntax highlighting for `.zx` files
- Auto-builds parser on first run if `tree-sitter` CLI is available

### File Icons
- Custom orange ZX icon in file explorers and pickers
- Supports both `nvim-web-devicons` and `mini.icons`

### LSP Support
- Automatic zls (Zig Language Server) integration for `.zx` files only
- Uses a separate `zls_zx` LSP instance - **does NOT interfere** with `.zig` file LSP
- Provides code completion, diagnostics, inlay hints, and other LSP features
- Custom diagnostic filtering: Silently filters out "expected expression, found '<'" errors (ZX blocks)
- **Smart initialization**: Automatically handles zls build configuration loading
  - First file open: LSP attaches, waits 3 seconds for build config, then auto-reattaches
  - Subsequent files: LSP works immediately

### Keymaps
- `<leader>zh`: Show highlight groups under cursor
- `<leader>zt`: Inspect Tree-sitter tree

## Requirements

- Neovim 0.9+
- `zls` in your PATH (install via zig package or standalone)
- Optional: `tree-sitter` CLI for auto-building parser

## Behavior

- **Auto-activation**: LSP automatically sets up when opening Neovim in a workspace with both `build.zig` and `site/` directory
- **Workspace detection**: Plugin detects zx projects and initializes proactively
- **Icon support**: Works with nvim-tree, telescope, lualine, bufferline, and other compatible plugins
- **Non-lazy loading**: Plugin loads on startup to ensure immediate LSP and icon support

