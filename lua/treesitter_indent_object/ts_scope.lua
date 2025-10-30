---From nvim-treesitter locals.lua (master branch)

local M = {}

---@param bufnr integer
---@return table
function M.get_locals(bufnr)
  local parser = vim.treesitter.get_parser(bufnr)
  local lang = parser:lang()
  local q = vim.treesitter.query.get(lang, "locals")
  if not q then
    return {}
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  return q:iter_matches(root, bufnr, 0, -1)
end

function M.get_scopes(bufnr)
  local locals = M.get_locals(bufnr)

  local scopes = {}

  for _, loc in ipairs(locals) do
    if loc["local"]["scope"] and loc["local"]["scope"].node then
      table.insert(scopes, loc["local"]["scope"].node)
    end
  end

  return scopes
end

---@param node TSNode
---@param bufnr? integer
---@param allow_scope? boolean
---@return TSNode|nil
function M.containing_scope(node, bufnr, allow_scope)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  local allow_scope = allow_scope == nil or allow_scope == true

  local scopes = M.get_scopes(bufnr)
  if not node or not scopes then
    return
  end

  local iter_node = node

  while iter_node ~= nil and not vim.tbl_contains(scopes, iter_node) do
    iter_node = iter_node:parent()
  end

  return iter_node or (allow_scope and node or nil)
end

return M
