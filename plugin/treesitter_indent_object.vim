
if exists('g:loaded_treesitter_indent_object')
    finish
endif
let g:loaded_treesitter_indent_object = 1

if !exists('g:__treesitter_indent_object_setup_completed')
    lua require("treesitter_indent_object").setup {}
endif
