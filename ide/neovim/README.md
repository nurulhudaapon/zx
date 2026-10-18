## Installation

```lua
-- ~/.config/nvim/lua/plugins/zx.lua
return {
    "ziex-dev/ziex",
    dependencies = { 
        "nvim-treesitter/nvim-treesitter",
        "neovim/nvim-lspconfig",  -- for LSP support
        "nvim-tree/nvim-web-devicons",  -- for file icons
    },
    -- Load on startup for immediate LSP and icon support
    lazy = false,
    priority = 50,
    config = function()
        vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/ziex/ide/neovim")
        vim.cmd("runtime! plugin/zx.lua")
    end,
}
```


## Language server

The plugin runs `zx lsp`, or `zig build zx -Dziex-lsp=true -- lsp` from the
nearest `build.zig` when the `zx` CLI is not installed. Set ZLS options in the
lazy.nvim `init` function:

```lua
init = function()
    vim.g.zx_zls_settings = { inlay_hints_show_builtin = true }
    -- vim.g.zx_lsp_cmd = { "/path/to/zx", "lsp" } -- optional override
end,
```

Without the plugin's LSP setup, pass options as `settings.zls`:

```lua
vim.lsp.config("zxls", {
    cmd = { "zx", "lsp" },
    filetypes = { "zx" },
    root_markers = { "build.zig", ".git" },
    settings = { zls = { inlay_hints_show_builtin = true } },
})
vim.lsp.enable("zxls")
```

See the [editor guide](../README.md) for the ZX defaults.
