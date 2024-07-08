local M = {}

-- taken from indent_blankline.utils
local _if = function(bool, a, b)
  if bool then
    return a
  else
    return b
  end
end

local get_variable = function(key)
  if vim.b[key] ~= nil then
    return vim.b[key]
  end
  if vim.t[key] ~= nil then
    return vim.t[key]
  end
  return vim.g[key]
end

M.first_not_nil = function(...)
  for _, value in pairs { ... } do -- luacheck: ignore
    return value
  end
end

M.error_handler = function(err, level)
  if err:match "Invalid buffer id.*" then
    return
  end
  if not pcall(require, "notify") then
    err = string.format("treesitter-indent-object: %s", err)
  end
  vim.notify_once(err, level or vim.log.levels.DEBUG, {
    title = "treesitter-indent-object",
  })
end

-- modified from indent_blankline.utils
-- to only care about getting indentation level
-- Used when treesitter is not available for the file type
-- If blankline, return huge value so it will be treated as always indented
M.find_indent = function(line_num)
  local expandtab = vim.bo.expandtab
  local tabs = vim.bo.shiftwidth == 0 or not expandtab
  local shiftwidth = _if(tabs, _if(no_tab_character, 2, vim.bo.tabstop), vim.bo.shiftwidth)
  local strict_tabs = get_variable "treesitter_indent_object_strict_tabs"

  local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
  local blankline = line:len() == 0
  if blankline then
    return 999999
  end
  local whitespace = string.match(line, "^%s+") or ""
  local only_whitespace = whitespace == line
  if only_whitespace then
    return 999999
  end

  local indent = 0
  local spaces = 0

  if whitespace then
    for ch in whitespace:gmatch "." do
      if ch == "\t" then
        if strict_tabs and indent == 0 and spaces ~= 0 then
          return 0
        end
        indent = indent + math.floor(spaces / shiftwidth) + 1
        spaces = 0
      else
        if strict_tabs and indent ~= 0 then
          -- return early when no more tabs are found
          return indent
        end
        spaces = spaces + 1
      end
    end
  end

  return indent + math.floor(spaces / shiftwidth)
end

-- Modified from indent_blankline.utils
-- to return column as well
M.get_current_context = function(type_patterns, use_treesitter_scope)
  local ts_utils_status, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
  if not ts_utils_status then
    vim.schedule_wrap(function()
      M.error_handler("nvim-treesitter not found. Context will not work", vim.log.levels.WARN)
    end)()
    return false
  end
  local locals = require "nvim-treesitter.locals"
  local cursor_node = ts_utils.get_node_at_cursor()

  if use_treesitter_scope then
    local current_scope = locals.containing_scope(cursor_node, 0)
    if not current_scope then
      return false
    end
    local start_row, start_col, end_row, end_col = current_scope:range()
    if start_row == end_row then
      return false
    end
    return true, current_scope, current_scope:type()
  end

  while cursor_node do
    local node_type = cursor_node:type()
    for _, rgx in ipairs(type_patterns) do
      if node_type:find(rgx) then
        local start_row, start_col, end_row, end_col = cursor_node:range()
        if start_row ~= end_row then
          return true, cursor_node, rgx
        end
      end
    end
    cursor_node = cursor_node:parent()
  end

  return false
end

return M
