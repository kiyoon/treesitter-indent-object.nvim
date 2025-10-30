local ts = vim.treesitter
local api = vim.api

local M = {}

M.avoid_force_reparsing = {
  yaml = true,
}

M.comment_parsers = {
  comment = true,
  jsdoc = true,
  phpdoc = true,
}

local function getline(lnum)
  return vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
end

---@param lnum integer
---@return integer
local function get_indentcols_at_line(lnum)
  local _, indentcols = getline(lnum):find("^%s*")
  return indentcols or 0
end

---@param root TSNode
---@param lnum integer
---@param col? integer
---@return TSNode
local function get_first_node_at_line(root, lnum, col)
  col = col or get_indentcols_at_line(lnum)
  return root:descendant_for_range(lnum - 1, col, lnum - 1, col + 1)
end

---@param root TSNode
---@param lnum integer
---@param col? integer
---@return TSNode
local function get_last_node_at_line(root, lnum, col)
  col = col or (#getline(lnum) - 1)
  return root:descendant_for_range(lnum - 1, col, lnum - 1, col + 1)
end

---@param node TSNode
---@return number
local function node_length(node)
  local _, _, start_byte = node:start()
  local _, _, end_byte = node:end_()
  return end_byte - start_byte
end

---@param bufnr integer
---@param node TSNode
---@param delimiter string
---@return TSNode|nil child
---@return boolean|nil is_end
local function find_delimiter(bufnr, node, delimiter)
  for child, _ in node:iter_children() do
    if child:type() == delimiter then
      local linenr = child:start()
      local line = vim.api.nvim_buf_get_lines(bufnr, linenr, linenr + 1, false)[1]
      local end_char = { child:end_() }
      local trimmed_after_delim
      local escaped_delimiter = delimiter:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1")
      trimmed_after_delim, _ = line:sub(end_char[2] + 1):gsub("[%s" .. escaped_delimiter .. "]*", "")
      return child, #trimmed_after_delim == 0
    end
  end
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

-- Caches indents per buffer+lang combination
local get_indents = (function()
  local cache = setmetatable({}, { __mode = "kv" })
  return function(bufnr, root, lang)
    local key = tostring(bufnr) .. "_" .. root:id() .. "_" .. lang
    if cache[key] then
      return cache[key]
    end

    local map = {
      ["indent.auto"] = {},
      ["indent.begin"] = {},
      ["indent.end"] = {},
      ["indent.dedent"] = {},
      ["indent.branch"] = {},
      ["indent.ignore"] = {},
      ["indent.align"] = {},
      ["indent.zero"] = {},
    }

    local query = ts.query.get(lang, "indents")
    if not query then
      cache[key] = map
      return map
    end

    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
      local name = query.captures[id]
      if name:sub(1, 1) ~= "_" then
        map[name][node:id()] = metadata or {}
      end
    end

    cache[key] = map
    return map
  end
end)()

---@param lnum integer (1-based line)
---@return integer indent amount in spaces
function M.get_indent(lnum)
  local bufnr = api.nvim_get_current_buf()
  local parser = ts.get_parser(bufnr)
  if not parser or not lnum then
    return -1
  end

  local lang = parser:lang() or vim.treesitter.language.get_lang(vim.bo.filetype)
  if not lang then
    return vim.fn.indent(lnum)
  end

  if not M.avoid_force_reparsing[lang] then
    parser:parse({ vim.fn.line("w0") - 1, vim.fn.line("w$") })
  end

  local root, lang_tree
  parser:for_each_tree(function(tstree, tree)
    if not tstree or M.comment_parsers[tree:lang()] then
      return
    end
    local local_root = tstree:root()
    if ts.is_in_node_range(local_root, lnum - 1, 0) then
      if not root or node_length(root) >= node_length(local_root) then
        root = local_root
        lang_tree = tree
      end
    end
  end)

  if not root then
    return 0
  end

  local q = get_indents(bufnr, root, lang_tree:lang())
  local is_empty = getline(lnum):match("^%s*$") ~= nil
  local node

  if is_empty then
    local prev = vim.fn.prevnonblank(lnum)
    local indentcols = get_indentcols_at_line(prev)
    local prevline = vim.trim(getline(prev))
    node = get_last_node_at_line(root, prev, indentcols + #prevline - 1)
    if node:type():match("comment") then
      local first_node = get_first_node_at_line(root, prev, indentcols)
      local _, scol = node:start()
      if first_node:id() ~= node:id() then
        prevline = vim.trim(prevline:sub(1, scol - indentcols))
        local col = indentcols + #prevline - 1
        node = get_last_node_at_line(root, prev, col)
      end
    end
    if q["indent.end"][node:id()] then
      node = get_first_node_at_line(root, lnum)
    end
  else
    node = get_first_node_at_line(root, lnum)
  end

  local indent_size = vim.fn.shiftwidth()
  local indent = 0
  local _, _, root_start = root:start()
  if root_start ~= 0 then
    indent = vim.fn.indent(root:start() + 1)
  end

  local processed = {}

  if q["indent.zero"][node:id()] then
    return 0
  end

  while node do
    local srow, _, erow = node:range()
    local is_processed = false

    -- Auto indent fallback
    if
      not q["indent.begin"][node:id()]
      and not q["indent.align"][node:id()]
      and q["indent.auto"][node:id()]
      and node:start() < lnum - 1
      and lnum - 1 <= node:end_()
    then
      return -1
    end

    -- Ignore blocks
    if
      not q["indent.begin"][node:id()]
      and q["indent.ignore"][node:id()]
      and node:start() < lnum - 1
      and lnum - 1 <= node:end_()
    then
      return 0
    end

    if
      not processed[srow]
      and ((q["indent.branch"][node:id()] and srow == lnum - 1) or (q["indent.dedent"][node:id()] and srow ~= lnum - 1))
    then
      indent = indent - indent_size
      is_processed = true
    end

    local should_process = not processed[srow]
    local parent = node:parent()
    local is_in_err = parent and parent:has_error() or false

    if
      should_process
      and q["indent.begin"][node:id()]
      and (srow ~= erow or is_in_err or q["indent.begin"][node:id()]["indent.immediate"])
      and (srow ~= lnum - 1 or q["indent.begin"][node:id()]["indent.start_at_same_line"])
    then
      indent = indent + indent_size
      is_processed = true
    end

    if is_in_err and not q["indent.align"][node:id()] then
      for c in node:iter_children() do
        if q["indent.align"][c:id()] then
          q["indent.align"][node:id()] = q["indent.align"][c:id()]
          break
        end
      end
    end

    if should_process and q["indent.align"][node:id()] and (srow ~= erow or is_in_err) and (srow ~= lnum - 1) then
      local meta = q["indent.align"][node:id()]
      local o_delim, o_last = find_delimiter(bufnr, node, meta["indent.open_delimiter"] or "")
      local c_delim, c_last = find_delimiter(bufnr, node, meta["indent.close_delimiter"] or "")
      local o_srow, o_scol = o_delim and o_delim:start() or {}
      local c_srow = c_delim and c_delim:start()
      local abs = false

      if o_last then
        indent = indent + indent_size
        if c_last and c_srow and c_srow < lnum - 1 then
          indent = math.max(indent - indent_size, 0)
        end
      else
        if c_last and c_srow and o_srow ~= c_srow and c_srow < lnum - 1 then
          indent = math.max(indent - indent_size, 0)
        else
          indent = o_scol + (meta["indent.increment"] or 1)
          abs = true
        end
      end

      local avoid_last = false
      if c_srow and c_srow ~= o_srow and c_srow == lnum - 1 then
        avoid_last = meta["indent.avoid_last_matching_next"] or false
      end
      if avoid_last and indent <= vim.fn.indent(o_srow + 1) + indent_size then
        indent = indent + indent_size
      end

      is_processed = true
      if abs then
        return indent
      end
    end

    processed[srow] = processed[srow] or is_processed
    node = node:parent()
  end

  return indent
end

return M
