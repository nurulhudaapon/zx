" ftdetect/zx.vim
" Filetype detection for ZX files
"
" NOTE: We treat .zx files as Zig files for LSP support
" The plugin/zx.lua handles the treesitter configuration

" Detect .zx files as Zig (for LSP)
autocmd BufRead,BufNewFile *.zx set filetype=zig

" Also support shebang detection if zx is used as a script
autocmd BufRead,BufNewFile * if getline(1) =~ '^#!.*\<zx\>' | setfiletype zig | endif

