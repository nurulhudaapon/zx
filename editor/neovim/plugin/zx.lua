-- Auto-register the zx filetype
vim.filetype.add({
    extension = {
      zx = 'zx',
    },
  })
  
  -- Register the parser with treesitter (modern API)
  vim.treesitter.language.register('zx', 'zx')
  
  -- Configure parser installation for nvim-treesitter (optional)
  -- This only runs if nvim-treesitter is installed
  local ok, parser_config = pcall(require, "nvim-treesitter.parsers")
  if ok and parser_config.get_parser_configs then
    -- Old API (for backward compatibility)
    local configs = parser_config.get_parser_configs()
    configs.zx = {
      install_info = {
        url = "https://github.com/nurulhudaapon/zx",
        files = {"tree-sitter-zx/src/parser.c"},
        branch = "main",
        generate_requires_npm = false,
      },
      filetype = "zx",
    }
  elseif ok then
    -- New API (Neovim 0.10+)
    local configs = require("nvim-treesitter.parsers")
    configs.zx = {
      install_info = {
        url = "https://github.com/nurulhudaapon/zx",
        files = {"tree-sitter-zx/src/parser.c"},
        branch = "main",
        generate_requires_npm = false,
      },
      filetype = "zx",
    }
  end