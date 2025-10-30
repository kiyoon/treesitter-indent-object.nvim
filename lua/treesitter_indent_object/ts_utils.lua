local M = {}

M.get_node_at_cursor = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local root
  parser:for_each_tree(function(tree)
    local r = tree:root()
    if r and vim.treesitter.is_in_node_range(r, row, col) then
      root = r
    end
  end)
  if not root then
    return nil
  end
  return root:named_descendant_for_range(row, col, row, col)
end

-- Get a compatible vim range (1 index based) from a TS node range.
--
-- TS nodes start with 0 and the end col is ending exclusive.
-- They also treat a EOF/EOL char as a char ending in the first
-- col of the next row.
---comment
---@param range integer[]
---@param buf integer|nil
---@return integer, integer, integer, integer
function M.get_vim_range(range, buf)
  ---@type integer, integer, integer, integer
  local srow, scol, erow, ecol = unpack(range)
  srow = srow + 1
  scol = scol + 1
  erow = erow + 1

  if ecol == 0 then
    -- Use the value of the last col of the previous row instead.
    erow = erow - 1
    if not buf or buf == 0 then
      ecol = vim.fn.col({ erow, "$" }) - 1
    else
      ecol = #vim.api.nvim_buf_get_lines(buf, erow - 1, erow, false)[1]
    end
    ecol = math.max(ecol, 1)
  end
  return srow, scol, erow, ecol
end

return M
