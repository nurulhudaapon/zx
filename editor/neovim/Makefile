# Makefile for nvim-zx development

.PHONY: help install test lint clean uninstall link

# Default target
help:
	@echo "nvim-zx Development Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make install   - Install plugin to Neovim"
	@echo "  make link      - Symlink plugin for development"
	@echo "  make test      - Open test file in Neovim"
	@echo "  make lint      - Lint tree-sitter queries"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make uninstall - Remove plugin from Neovim"
	@echo "  make build     - Build tree-sitter parser"

# Install plugin to Neovim
install:
	@echo "Installing nvim-zx..."
	@mkdir -p ~/.local/share/nvim/site/pack/zx/start/
	@cp -r . ~/.local/share/nvim/site/pack/zx/start/nvim-zx
	@echo "✓ Plugin installed to ~/.local/share/nvim/site/pack/zx/start/nvim-zx"
	@echo "Add to your init.lua: require('nvim-zx').setup()"

# Symlink for development
link:
	@echo "Creating development symlink..."
	@mkdir -p ~/.local/share/nvim/site/pack/zx/start/
	@ln -sf $(PWD) ~/.local/share/nvim/site/pack/zx/start/nvim-zx
	@echo "✓ Development symlink created"
	@echo "Changes will be reflected immediately in Neovim"

# Build tree-sitter parser
build:
	@echo "Building tree-sitter-zx parser..."
	@cd ../../tree-sitter-zx && npm install && npm run build
	@echo "✓ Parser built successfully"

# Open test file
test:
	@echo "Opening test file..."
	@nvim test/sample.zx

# Lint tree-sitter queries
lint:
	@echo "Linting tree-sitter queries..."
	@nvim --headless -c "lua vim.treesitter.query.lint('queries/zx/highlights.scm')" -c "q" 2>&1 | grep -v "^$$"
	@echo "✓ Queries linted"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@find . -name "*.swp" -delete
	@find . -name "*.swo" -delete
	@find . -name "*~" -delete
	@rm -rf parser/
	@echo "✓ Cleaned"

# Uninstall plugin
uninstall:
	@echo "Uninstalling nvim-zx..."
	@rm -rf ~/.local/share/nvim/site/pack/zx/start/nvim-zx
	@echo "✓ Plugin uninstalled"

# Development workflow
dev: link build test
	@echo "✓ Development environment ready!"

# Check installation
check:
	@echo "Checking nvim-zx installation..."
	@nvim --headless -c "lua print(require('nvim-zx').get_info())" -c "q" 2>&1

# Generate help tags
helptags:
	@echo "Generating help tags..."
	@nvim --headless -c "helptags doc/" -c "q"
	@echo "✓ Help tags generated"
	@echo "Access with :help nvim-zx"



