# Treesitter-indent-object.nvim

`vai` to select current context!

Context-aware smart indent object to select block, powered by [treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

<img src="https://user-images.githubusercontent.com/12980409/206920869-0a9075e2-7688-4c54-a442-331239a61de2.gif" width="100%"/>

This plugin is intended to be used with [indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim),
so you see the scope before you select.

## Install

Use your favourite plugin manager to install.

#### Example with lazy.nvim

This includes lazy-loading on keymaps. If you install like this, you can ignore every instruction below.
```lua
  {
    "kiyoon/treesitter-indent-object.nvim",
    keys = {
      {
        "ai",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>",
        mode = {"x", "o"},
        desc = "Select context-aware indent (outer)",
      },
      {
        "aI",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer(true)<CR>",
        mode = {"x", "o"},
        desc = "Select context-aware indent (outer, line-wise)",
      },
      {
        "ii",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>",
        mode = {"x", "o"},
        desc = "Select context-aware indent (inner, partial range)",
      },
      {
        "iI",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>",
        mode = {"x", "o"},
        desc = "Select context-aware indent (inner, entire range)",
      },
    },
  },
```

<details>
  <summary>Click to see instructions for packer and vim-plug</summary>
  
#### Example with Packer

[wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- init.lua
require("packer").startup(function()
  use "nvim-treesitter/nvim-treesitter"
  use "lukas-reineke/indent-blankline.nvim"  -- optional
  use "kiyoon/treesitter-indent-object.nvim"
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
omap ai <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>
" vaI to ensure selecting entire line (or just use Vai)
xmap aI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer(true)<CR>
omap aI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer(true)<CR>
" vii to select inner block (only if block, only else block, etc.)
xmap ii <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>
omap ii <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>
" viI to select entire inner range (including if, else, etc.)
xmap iI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>
omap iI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>
```

Lua equivalent:  

```lua
-- select context-aware indent
vim.keymap.set({"x", "o"}, "ai", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>")
-- ensure selecting entire line (or just use Vai)
vim.keymap.set({"x", "o"}, "aI", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer(true)<CR>")
-- select inner block (only if block, only else block, etc.)
vim.keymap.set({"x", "o"}, "ii", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>")
-- select entire inner range (including if, else, etc.)
vim.keymap.set({"x", "o"}, "iI", "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>")
```

  </details>
