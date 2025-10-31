# Treesitter-indent-object.nvim

`vai` to select current context!

Context-aware smart indent object to select block, powered by [treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

<img src="https://user-images.githubusercontent.com/12980409/206920869-0a9075e2-7688-4c54-a442-331239a61de2.gif" width="100%"/>

This plugin is intended to be used with [indent-blankline-v2.nvim](https://github.com/kiyoon/indent-blankline-v2.nvim),
so you see the scope before you select.

> [!NOTE]
> **This plugin is only compatible with `indent-blankline.nvim` v2** because its definition of scope has been changed on v3.
> TL;DR - v2 scope is just "same indent level" while v3 uses an actual [semantic scope][scope] specific to each language.
> My personal preference is to keep using v2 as its scope aligns well with VSCode.
> The author does seem to plan on bringing back the old scope on v3 ([lukas-reineke/indent-blankline.nvim#649][issue]).
>
> - Use the fork [kiyoon/indent-blankline-v2.nvim](https://github.com/kiyoon/indent-blankline-v2.nvim) for v2 maintenance, like using `main` branch of `nvim-treesitter` is supported.

[scope]: https://en.wikipedia.org/wiki/Scope_(computer_science)
[issue]: https://github.com/lukas-reineke/indent-blankline.nvim/issues/649


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
        function() require'treesitter_indent_object.textobj'.select_indent_outer() end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer)",
      },
      {
        "aI",
        function()
          require'treesitter_indent_object.textobj'.select_indent_outer(true, 'V')
          require'treesitter_indent_object.refiner'.include_surrounding_empty_lines()
        end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer, line-wise)",
      },
      {
        "ii",
        function() require'treesitter_indent_object.textobj'.select_indent_inner() end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, partial range)",
      },
      {
        "iI",
        function() require'treesitter_indent_object.textobj'.select_indent_inner(true, 'V') end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, entire range) in line-wise visual mode",
      },
    },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    tag = "v2.20.8",  -- Use v2
    event = "BufReadPost",
    config = function()
      vim.opt.list = true
      require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
      }
    end,
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
" viI to select entire inner range (including if, else, etc.) in line-wise visual mode
xmap iI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true, 'V')<CR>
omap iI <Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true, 'V')<CR>
```

Lua equivalent:

```lua
-- select context-aware indent
vim.keymap.set({"x", "o"}, "ai", function() require'treesitter_indent_object.textobj'.select_indent_outer() end)
-- ensure selecting entire line (or just use Vai)
vim.keymap.set({"x", "o"}, "aI", function() require'treesitter_indent_object.textobj'.select_indent_outer(true) end)
-- select inner block (only if block, only else block, etc.)
vim.keymap.set({"x", "o"}, "ii", function() require'treesitter_indent_object.textobj'.select_indent_inner() end)
-- select entire inner range (including if, else, etc.) in line-wise visual mode
vim.keymap.set({"x", "o"}, "iI", function() require'treesitter_indent_object.textobj'.select_indent_inner(true, 'V') end)
```

</details>

## Tips and Tricks

#### Include Surrounding Whitespace

There is a helper function that expands current selection to the surrounding empty lines.
Call it right after the textobject and it'll try to match the behavior of the builtin `ap` (a paragraph) keymap.
See [#4](https://github.com/kiyoon/treesitter-indent-object.nvim/pull/4) for more details about its behavior.

> [!NOTE]
> This function is designed to work with line-wise selections (`'V'`) only!

```lua
{
  "aI",
  function()
    require'treesitter_indent_object.textobj'.select_indent_outer(true, 'V')
    require'treesitter_indent_object.refiner'.include_surrounding_empty_lines()
  end,
  mode = { "x", "o" },
},
```
