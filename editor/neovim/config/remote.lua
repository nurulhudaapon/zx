-- ~/.config/nvim/lua/plugins/zx.lua
return {
    "nurulhudaapon/zx",
    dependencies = { 
        "nvim-treesitter/nvim-treesitter",
        "neovim/nvim-lspconfig",  -- for LSP support
        "nvim-tree/nvim-web-devicons",  -- for file icons
    },
    -- Load on startup instead of lazy-loading on filetype
    -- This ensures LSP and icons are ready immediately
    lazy = false,
    priority = 50,  -- Load after lspconfig but early
    config = function()
        vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/zx/editor/neovim")
        vim.cmd("runtime! plugin/zx.lua")
    end,
}
