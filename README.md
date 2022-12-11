# Treesitter-indent-object.nvim

`vai` to select current context!

Context-aware smart indent object to select block, powered by [treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

This plugin is intended to be used with [indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim),
so you see the scope before you select.

## Install

Use your favourite plugin manager to install.

#### Example with Packer

[wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- init.lua
require("packer").startup(function()
  use "nvim-treesitter/nvim-treesitter"
  use "lukas-reineke/indent-blankline.nvim"  -- optional
  use "treesitter-indent-object-nvim"
end)
```

#### Example with Plug

[junegunn/vim-plug](https://github.com/junegunn/vim-plug)

```vim
" init.vim
call plug#begin('~/.vim/plugged')
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'lukas-reineke/indent-blankline.nvim'  " optional
Plug 'kiyoon/treesitter-indent-object.nvim'
call plug#end()
```

## Setup

`setup()` is not required, but here is the recommendation.

```lua
require("indent_blankline").setup {
    show_current_context = true,
    show_current_context_start = true,
}

-- Actually, no setup is required, but
-- if setup comes after the indent_blankline,
-- it will try to follow the pattern matching options
-- used in indent_blankline
require("treesitter_indent_object").setup()
```

Key bindings are not configured by default.  
Here are some examples.

```vim
" vai to select context-aware indent
xmap ai <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>
" select inner block (only if block, only else block, etc.)
xmap ii <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>
" select entire inner range (including if, else, etc.)
xmap iI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>

" optional
" vaI to ensure select entire line (or just use Vai)
xnoremap aI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>o^og
```

Lua equivalent:  

```lua
-- select context-aware indent
vim.keymap.set("x", "ai", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>")
-- select inner block (only if block, only else block, etc.)
vim.keymap.set("x", "ii", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>")
-- select entire inner range (including if, else, etc.)
vim.keymap.set("x", "iI", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>")
```

