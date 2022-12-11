local folderOfThisFile = (...):match("(.-)[^%.]+$")
local utils = require(folderOfThisFile .. ".utils")
local M = {}

M.setup = function(options)
    if options == nil then
        options = {}
    end

    local o = utils.first_not_nil

    vim.g.indent_blankline_context_patterns = o(options.context_patterns, vim.g.treesitter_indent_object_context_patterns, vim.g.indent_blankline_context_patterns, {
        "class",
        "^func",
        "method",
        "^if",
        "while",
        "for",
        "with",
        "try",
        "except",
        "arguments",
        "argument_list",
        "object",
        "dictionary",
        "element",
        "table",
        "tuple",
        "do_block",
    })

    vim.g.treesitter_indent_object_use_treesitter_scope =
        o(options.use_treesitter_scope, vim.g.treesitter_indent_object_use_treesitter_scope, vim.g.indent_blankline_use_treesitter_scope, false)

    vim.g.__treesitter_indent_object_setup_completed = true
end
return M
