local utils = require("treesitter_indent_object.utils")

local ts_query_status, ts_query = pcall(require, "nvim-treesitter.query")
if not ts_query_status then
  vim.schedule_wrap(function()
    utils.error_handler("nvim-treesitter not found. Treesitter indent will not work", vim.log.levels.WARN)
  end)()
end

local ts_utils_status, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
local ts_indent_status, ts_indent = pcall(require, "nvim-treesitter.indent")

local M = {}


local enter_visual_mode = function(force_mode)
  -- enter visual mode if normal or operator-pending (no) mode
  -- Why? According to https://learnvimscriptthehardway.stevelosh.com/chapters/15.html
  --   If your operator-pending mapping ends with some text visually selected, Vim will operate on that text.
  --   Otherwise, Vim will operate on the text between the original cursor position and the new position.
  local mode = vim.api.nvim_get_mode()

  -- If set to 'V', try to force line-wise visual mode
  if force_mode == 'V' then
    if mode.mode == 'no' or mode.mode == 'n' or mode.mode == 'v' then
      vim.cmd("normal! V")
    end
  -- If set to 'v', try to force char-wise visual mode
  elseif force_mode == 'v' then
    if mode.mode == 'no' or mode.mode == 'n' or mode.mode == 'V' then
      vim.cmd("normal! v")
    end
  -- If not specified, respect the current visual mode
  else
    if mode.mode == 'no' or mode.mode == 'n' then
      vim.cmd("normal! v")
    end
  end
end

-- Assume it is already visual mode
local update_selection = function (node, entire_line)
  local start_row, start_col, end_row, end_col = ts_utils.get_vim_range( {node:range()} )
  vim.api.nvim_win_set_cursor(0, {start_row, start_col-1})
  if entire_line then
    vim.cmd("normal! ^")
  end
  vim.cmd("normal! o")
  vim.api.nvim_win_set_cursor(0, {end_row, end_col-1})
  if entire_line then
    vim.cmd("normal! g_")
  end
end

M.select_indent_outer = function(entire_line, force_mode)
  entire_line = entire_line or false
  -- We have to remember that end_col is end-exclusive
  local context_status, context_node, context_pattern =
    utils.get_current_context(vim.g.treesitter_indent_object_context_patterns, vim.g.treesitter_indent_object_use_treesitter_scope)
  if not context_status then return false end

  enter_visual_mode(force_mode)
  update_selection(context_node, entire_line)
end

M.select_indent_inner = function(select_all, force_mode)
  select_all = select_all or false
  local use_ts_indent = ts_query_status and ts_indent_status and ts_query.has_indents(vim.bo.filetype)
  local indent_fn = nil
  if use_ts_indent then
    indent_fn = ts_indent.get_indent
  else
    indent_fn = utils.find_indent
  end

  -- We have to remember that end_col is end-exclusive
  local context_status, context_node, context_pattern =
    utils.get_current_context(vim.g.treesitter_indent_object_context_patterns, vim.g.treesitter_indent_object_use_treesitter_scope)
  if not context_status then return false end

  local start_row, _, end_row, _ = ts_utils.get_vim_range( {context_node:range()} )
  local start_indent = indent_fn(start_row)

  local indented_row_start = nil
  local indented_row_end = nil
  if select_all then
    -- inner select all mode: remove first and last non-indented lines (e.g. if, end)
    -- but include the one in the middle (e.g. else)
    for i = start_row, end_row do
      local indent = indent_fn(i)
      if indent > start_indent then
        indented_row_start = i
        break
      end
    end

    if indented_row_start == nil then
      return false
    end

    for i = end_row, start_row, -1 do
      local indent = indent_fn(i)
      if indent > start_indent then
        indented_row_end = i
        break
      end
    end

    if indented_row_end == nil then
      -- this should not happen
      return false
    end
  else  -- select one block
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_row = cursor_pos[1]

    if indent_fn(cursor_row) == start_indent then
      for i = cursor_row, end_row do
        -- search downwards for the first indented line
        local indent = indent_fn(i)
        if indent > start_indent then
          indented_row_start = i
          break
        end
      end

      if indented_row_start == nil then
        -- reached the end without finding the start
        -- search upwards for end and then further up for start
        for i = cursor_row, start_row, -1 do
          local indent = indent_fn(i)
          if indent > start_indent then
            indented_row_end = i
            break
          end
        end

        if indented_row_end == nil then
          -- no indents at all within the context (scope)
          return false
        end

        indented_row_start = start_row
        for i = indented_row_end, start_row, -1 do
          local indent = indent_fn(i)
          if indent == start_indent then
            indented_row_start = i+1
            break
          end
        end
      else
        -- Found the start
        -- search further down for end
        -- languages like Python will end with an indented line
        indented_row_end = end_row
        for i = indented_row_start, end_row do
          local indent = indent_fn(i)
          if indent == start_indent then
            indented_row_end = i-1
            break
          end
        end
      end
    else
      -- cursor is already in a indented line
      indented_row_start = start_row
      for i = cursor_row, start_row, -1 do
        -- search upwards for the first non-indented line
        local indent = indent_fn(i)
        if indent == start_indent then
          indented_row_start = i+1
          break
        end
      end

      -- languages like Python will end with an indented line
      indented_row_end = end_row
      for i = cursor_row, end_row do
        -- search downwards for the first non-indented line
        local indent = indent_fn(i)
        if indent == start_indent then
          indented_row_end = i-1
          break
        end
      end
    end
    -- inner mode: select one of the intermediate children
    -- whose indent is deeper than the current context (e.g. body of a function, if etc.)
    -- and if multiple, select the one close to the cursor
    -- comments and body are separated. We want to select both so we can't just select the first indented child.
    -- local children = ts_utils.get_named_children(context_node)
    -- local children_with_indent = {}
    -- for i = 1, #children do
    --   child_start_row, _, child_end_row, _ = ts_utils.get_vim_range( {children[i]:range()} )
    --   for j = child_start_row, child_end_row do
    --     print(ts_indent.get_indent(j), j)
    --     if ts_indent.get_indent(j) > start_indent then
    --       if child_start_row <= cursor_pos[1] and cursor_pos[1] <= child_end_row then
    --         -- immediately update if cursor includes the node
    --         update_selection(children[i])
    --       end
    --       table.insert(children_with_indent, children[i])
    --     end
    --   end
    -- end
  end

  enter_visual_mode(force_mode)
  vim.api.nvim_win_set_cursor(0, {indented_row_start, 0})
  vim.cmd("normal! ^o")
  vim.api.nvim_win_set_cursor(0, {indented_row_end, 0})
  vim.cmd("normal! g_")

  return true
end

return M
