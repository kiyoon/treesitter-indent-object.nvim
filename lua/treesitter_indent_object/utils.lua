local M = {}

-- taken from indent_blankline.utils
M.first_not_nil = function(...)
  for _, value in pairs { ... } do -- luacheck: ignore
    return value
  end
end

-- taken from indent_blankline.utils
M.error_handler = function(err, level)
    if err:match "Invalid buffer id.*" then
        return
    end
    if not pcall(require, "notify") then
        err = string.format("indent-blankline: %s", err)
    end
    vim.notify_once(err, level or vim.log.levels.DEBUG, {
        title = "indent-blankline",
    })
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
