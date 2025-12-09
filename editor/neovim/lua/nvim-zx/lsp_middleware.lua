-- lua/nvim-zx/lsp_middleware.lua
-- LSP middleware for filtering/modifying zls diagnostics for ZX files

local M = {}

-- Configuration
M.config = {
  -- Filter diagnostics related to ZX syntax
  filter_zx_diagnostics = true,
  
  -- Convert ZX syntax errors to hints instead of errors
  convert_to_hints = true,
  
  -- Enable custom formatting for ZX files
  enable_formatting = true,
}

-- Patterns that indicate ZX syntax errors from zls
local ZX_ERROR_PATTERNS = {
  "expected expression, found '<'",
  "expected expression, found '>'",
  "expected ';', found '<'",
  "expected ';', found '>'",
  "invalid token: '<'",
  "invalid token: '>'",
  "unexpected token: '<'",
  "unexpected token: '>'",
}

-- Check if a diagnostic message matches ZX syntax patterns
local function is_zx_syntax_diagnostic(message)
  for _, pattern in ipairs(ZX_ERROR_PATTERNS) do
    if message:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

-- Filter and modify diagnostics for ZX files
function M.filter_diagnostics(diagnostics, bufnr)
  if not M.config.filter_zx_diagnostics then
    return diagnostics
  end
  
  local filtered = {}
  
  for _, diag in ipairs(diagnostics) do
    local should_include = true
    local modified_diag = vim.deepcopy(diag)
    
    -- Check if this is a ZX syntax diagnostic
    if is_zx_syntax_diagnostic(diag.message) then
      if M.config.convert_to_hints then
        -- Convert error to hint
        modified_diag.severity = vim.diagnostic.severity.HINT
        modified_diag.message = "ZX syntax: minimal LSP support available (this is not an error)"
      else
        -- Filter it out completely
        should_include = false
      end
    end
    
    -- Check for other common ZX-related errors
    if diag.message:match("expected '%;'") and diag.message:match("found '<'") then
      if M.config.convert_to_hints then
        modified_diag.severity = vim.diagnostic.severity.HINT
        modified_diag.message = "ZX syntax detected (not a Zig error)"
      else
        should_include = false
      end
    end
    
    if should_include then
      table.insert(filtered, modified_diag)
    end
  end
  
  return filtered
end

-- Custom diagnostic handler
function M.setup_diagnostic_handler()
  local original_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]
  
  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    -- Get buffer number
    local bufnr = vim.uri_to_bufnr(result.uri)
    
    -- Check if this is a .zx file
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local is_zx_file = filename:match("%.zx$")
    
    if is_zx_file and result.diagnostics then
      -- Filter diagnostics for .zx files
      result.diagnostics = M.filter_diagnostics(result.diagnostics, bufnr)
    end
    
    -- Call original handler
    return original_handler(err, result, ctx, config)
  end
end

-- Custom formatting handler for ZX files
function M.setup_formatting_handler()
  local original_formatting = vim.lsp.handlers["textDocument/formatting"]
  
  vim.lsp.handlers["textDocument/formatting"] = function(err, result, ctx, config)
    if not M.config.enable_formatting then
      return original_formatting(err, result, ctx, config)
    end
    
    local bufnr = ctx.bufnr
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local is_zx_file = filename:match("%.zx$")
    
    if is_zx_file then
      -- For ZX files, we might want custom formatting behavior
      -- For now, we'll let zig fmt handle what it can
      vim.notify(
        "ZX formatting: zig fmt may not handle ZX syntax. Use with caution.",
        vim.log.levels.WARN
      )
    end
    
    return original_formatting(err, result, ctx, config)
  end
end

-- Custom hover handler
function M.setup_hover_handler()
  local original_hover = vim.lsp.handlers["textDocument/hover"]
  
  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
    -- You can add custom hover behavior here if needed
    -- For now, just pass through to original handler
    return original_hover(err, result, ctx, config)
  end
end

-- Setup all handlers
function M.setup(user_config)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
  
  -- Setup handlers
  M.setup_diagnostic_handler()
  M.setup_formatting_handler()
  M.setup_hover_handler()
  
  vim.notify("nvim-zx: LSP middleware enabled", vim.log.levels.INFO)
end

-- Function to toggle diagnostic filtering on/off
function M.toggle_diagnostic_filter()
  M.config.filter_zx_diagnostics = not M.config.filter_zx_diagnostics
  local status = M.config.filter_zx_diagnostics and "enabled" or "disabled"
  vim.notify("ZX diagnostic filtering " .. status, vim.log.levels.INFO)
  
  -- Refresh diagnostics
  vim.diagnostic.reset()
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == "zls" then
      vim.lsp.buf_request(0, "textDocument/diagnostic", {
        textDocument = vim.lsp.util.make_text_document_params()
      })
    end
  end
end

-- Function to add custom error patterns
function M.add_error_pattern(pattern)
  table.insert(ZX_ERROR_PATTERNS, pattern)
end

-- Function to remove error patterns
function M.remove_error_pattern(pattern)
  for i, p in ipairs(ZX_ERROR_PATTERNS) do
    if p == pattern then
      table.remove(ZX_ERROR_PATTERNS, i)
      return true
    end
  end
  return false
end

-- Get current configuration
function M.get_config()
  return vim.deepcopy(M.config)
end

return M



