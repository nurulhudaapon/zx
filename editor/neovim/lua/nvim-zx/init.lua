-- lua/nvim-zx/init.lua
-- Main initialization module for nvim-zx

local M = {}

-- Default configuration
local default_config = {
  parser_path = nil,  -- Will auto-detect from plugin directory
  highlight = true,
  indent = true,
  
  -- LSP middleware configuration
  lsp = {
    enable_middleware = true,
    filter_zx_diagnostics = true,
    convert_to_hints = true,
    enable_formatting = true,
  },
}

-- Get the path to the tree-sitter-zx parser
local function get_parser_path()
  -- Try to find the parser relative to this plugin
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  local parser_dir = vim.fn.fnamemodify(plugin_dir, ":h:h") .. "/tree-sitter-zx"
  
  if vim.fn.isdirectory(parser_dir) == 1 then
    return parser_dir
  end
  
  -- Fallback: look in common locations
  local fallback_paths = {
    vim.fn.getcwd() .. "/tree-sitter-zx",
    vim.fn.expand("~/.local/share/tree-sitter-zx"),
  }
  
  for _, path in ipairs(fallback_paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end
  
  return nil
end

-- Register the ZX parser with nvim-treesitter
local function register_parser(config)
  local parser_path = config.parser_path or get_parser_path()
  
  if not parser_path then
    vim.notify(
      "nvim-zx: Could not find tree-sitter-zx parser. Please specify parser_path in setup().",
      vim.log.levels.WARN
    )
    return
  end
  
  -- Add parser directory to runtimepath so Neovim can find it
  vim.opt.runtimepath:append(parser_path)
  
  -- Register ZX parser for use with 'zig' filetype
  -- This allows .zx files to be treated as Zig for LSP while using ZX treesitter
  pcall(vim.treesitter.language.register, "zx", "zig")
  
  -- Also register for 'zx' filetype in case someone wants to use it directly
  pcall(vim.treesitter.language.register, "zx", "zx")
  
  -- Try to configure with nvim-treesitter if available (for :TSInstall, etc.)
  local has_ts_configs, ts_configs = pcall(require, "nvim-treesitter.parsers")
  if has_ts_configs then
    -- Try to get parser configs (old API)
    local ok, get_configs = pcall(function() return ts_configs.get_parser_configs end)
    if ok and get_configs and type(get_configs) == "function" then
      local configs = get_configs()
      if configs then
        configs.zx = {
          install_info = {
            url = parser_path,
            files = { "src/parser.c" },
            branch = "main",
            generate_requires_npm = true,
            requires_generate_from_grammar = false,
          },
          filetype = "zig",  -- Changed from "zx" to "zig"
          maintainers = { "@nurulhudaapon" },
        }
      end
    end
  end
  
  vim.notify("nvim-zx: Parser registered (using Zig filetype for LSP support)", vim.log.levels.INFO)
end

-- Setup LSP for .zx files (treat as Zig)
local function setup_lsp()
  -- Extend Zig LSP to .zx files
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = "*.zx",
    callback = function()
      -- Get LSP clients attached to zig filetype
      local clients = vim.lsp.get_active_clients()
      for _, client in ipairs(clients) do
        if client.name == "zls" or client.config.filetypes and vim.tbl_contains(client.config.filetypes, "zig") then
          -- Attach to current buffer
          vim.lsp.buf_attach_client(0, client.id)
        end
      end
    end,
  })
end

-- Setup function
function M.setup(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  
  -- Register the parser
  register_parser(config)
  
  -- Setup LSP for .zx files
  setup_lsp()
  
  -- Setup LSP middleware if enabled
  if config.lsp and config.lsp.enable_middleware then
    local middleware = require('nvim-zx.lsp_middleware')
    middleware.setup({
      filter_zx_diagnostics = config.lsp.filter_zx_diagnostics,
      convert_to_hints = config.lsp.convert_to_hints,
      enable_formatting = config.lsp.enable_formatting,
    })
  end
  
  -- Setup highlighting if enabled (now applies to .zx files treated as zig)
  if config.highlight then
    vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
      pattern = "*.zx",
      callback = function()
        if vim.fn.exists(":TSBufEnable") > 0 then
          vim.cmd("TSBufEnable highlight")
        end
      end,
    })
  end
  
  -- Setup indentation if enabled
  if config.indent then
    vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
      pattern = "*.zx",
      callback = function()
        if vim.fn.exists(":TSBufEnable") > 0 then
          vim.cmd("TSBufEnable indent")
        end
      end,
    })
  end
end

-- Utility function to check if ZX parser is loaded
function M.is_parser_loaded()
  -- Check if we can get a parser for zx language
  local ok, _ = pcall(vim.treesitter.language.inspect, "zx")
  return ok
end

-- Get parser info
function M.get_info()
  local info = {
    parser_loaded = M.is_parser_loaded(),
    treesitter_available = pcall(require, "nvim-treesitter"),
    lsp_middleware_available = pcall(require, "nvim-zx.lsp_middleware"),
  }
  
  print(vim.inspect(info))
  return info
end

-- Expose middleware functions
function M.toggle_diagnostic_filter()
  local middleware = require('nvim-zx.lsp_middleware')
  middleware.toggle_diagnostic_filter()
end

function M.get_lsp_config()
  local middleware = require('nvim-zx.lsp_middleware')
  return middleware.get_config()
end

function M.add_error_pattern(pattern)
  local middleware = require('nvim-zx.lsp_middleware')
  middleware.add_error_pattern(pattern)
end

return M

