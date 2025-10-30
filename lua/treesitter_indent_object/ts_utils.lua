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

--- Check whether Treesitter indent queries exist for a given filetype
---@param ft string? filetype (defaults to current buffer)
---@return boolean
M.has_indents = function(ft)
  ft = ft or vim.bo.filetype

  -- Treesitter "language" usually matches filetype,
  -- but we can normalize with vim.treesitter.language.inspect_lang if needed
  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then
    return false
  end

  -- Look for any matching indents.scm files
  local files = vim.api.nvim_get_runtime_file(("queries/%s/indents.scm"):format(lang), true)
  return files and #files > 0
end

---@param lnum integer (1-based line)
---@return integer indent amount in spaces
function M.get_indent(lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return -1
  end

  -- Treesitter uses 0-based indexing internally
  local line = lnum - 1
  local root ---@type TSNode|nil
  parser:for_each_tree(function(tstree)
    local local_root = tstree:root()
    if
      vim.treesitter.is_in_node_range(local_root, line, 0)
      and (not root or local_root:byte_length() < root:byte_length())
    then
      root = local_root
    end
  end)
  if not root then
    return 0
  end

  -- Load indent query (built-in now!)
  local lang = parser:lang() or vim.treesitter.language.get_lang(vim.bo.filetype)
  local query = vim.treesitter.query.get(lang, "indents")
  if not query then
    return vim.fn.indent(lnum)
  end

  local indent_size = vim.fn.shiftwidth()
  local indent = 0
  local node = root:named_descendant_for_range(line, 0, line, 0)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  local is_empty_line = buf_lines[1] and buf_lines[1]:match("^%s*$") ~= nil

  -- Short-circuit: empty line, use previous non-empty line’s indent
  if is_empty_line then
    local prev = vim.fn.prevnonblank(lnum)
    if prev > 0 then
      return vim.fn.indent(prev)
    end
    return 0
  end

  -- Collect all captures once
  local captures = {}
  for id, cap_node, metadata in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    captures[cap_node:id()] = { name = name, meta = metadata }
  end

  -- Walk up node chain applying indent rules
  while node do
    local cap = captures[node:id()]
    if cap then
      if cap.name == "indent.zero" then
        return 0
      elseif cap.name == "indent.begin" then
        indent = indent + indent_size
      elseif cap.name == "indent.end" or cap.name == "indent.dedent" then
        indent = indent - indent_size
      elseif cap.name == "indent.align" and cap.meta["indent.increment"] then
        indent = indent + indent_size * (cap.meta["indent.increment"] or 1)
      end
    end
    node = node:parent()
  end

  return math.max(indent, 0)
end

return M
