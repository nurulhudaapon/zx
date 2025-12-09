-- plugin/zx.lua
-- Filetype detection for ZX files
--
-- STRATEGY: Treat .zx files as Zig files for LSP, but use ZX treesitter for highlighting
-- This gives us:
-- - Full Zig LSP support (autocomplete, diagnostics, go-to-definition, etc.)
-- - ZX-specific syntax highlighting (tags, attributes, etc.)
-- - Zig formatting and other Zig tooling

-- Register .zx files with compound filetype: zig with zx treesitter
vim.filetype.add({
  extension = {
    zx = function()
      -- Set filetype to 'zig' for LSP attachment
      vim.bo.filetype = "zig"
      -- But use 'zx' treesitter parser for syntax highlighting
      vim.treesitter.language.register("zx", "zig")
      return "zig"
    end,
  },
  pattern = {
    [".*%.zx"] = function()
      vim.bo.filetype = "zig"
      vim.treesitter.language.register("zx", "zig")
      return "zig"
    end,
  },
})

-- Set up .zx file behavior (inherits most from Zig)
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*.zx",
  callback = function()
    -- Explicitly set filetype to zig for LSP
    vim.bo.filetype = "zig"
    
    -- Force treesitter to use the zx parser for this buffer
    local buf = vim.api.nvim_get_current_buf()
    vim.treesitter.language.register("zx", "zig")
    
    -- Override default Zig settings if needed
    -- (Most settings will be inherited from Zig filetype)
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4  -- Zig standard
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    
    -- Comment string (same as Zig)
    vim.opt_local.commentstring = "// %s"
    
    -- Enable tree-sitter folding if available
    if vim.fn.has("nvim-0.9.0") == 1 then
      vim.opt_local.foldmethod = "expr"
      vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
      vim.opt_local.foldenable = false
    end
  end,
})

-- User commands for ZX plugin
vim.api.nvim_create_user_command("ZxToggleDiagnosticFilter", function()
  require('nvim-zx').toggle_diagnostic_filter()
end, {
  desc = "Toggle ZX diagnostic filtering on/off"
})

vim.api.nvim_create_user_command("ZxInfo", function()
  require('nvim-zx').get_info()
end, {
  desc = "Show nvim-zx plugin information"
})

vim.api.nvim_create_user_command("ZxLspConfig", function()
  local config = require('nvim-zx').get_lsp_config()
  print("ZX LSP Configuration:")
  print(vim.inspect(config))
end, {
  desc = "Show ZX LSP middleware configuration"
})

vim.api.nvim_create_user_command("ZxAddErrorPattern", function(opts)
  if opts.args == "" then
    vim.notify("Usage: ZxAddErrorPattern <pattern>", vim.log.levels.WARN)
    return
  end
  require('nvim-zx').add_error_pattern(opts.args)
  vim.notify("Added error pattern: " .. opts.args, vim.log.levels.INFO)
end, {
  nargs = 1,
  desc = "Add custom error pattern to filter"
})

