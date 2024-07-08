local M = {}

---Expand the linewise visual selection to the surrounding empty lines.
M.include_surrounding_empty_lines = function()
  local cur = vim.fn.line "."
  local eob = vim.fn.line "$"

  -- expand the selection to the empty lines below
  local i = cur
  while i < eob and vim.fn.getline(i + 1):match "^%s*$" ~= nil do
    i = i + 1
  end
  vim.api.nvim_win_set_cursor(0, { i, 99999 })

  -- if: there were no empty lines below (cursor did not move)
  -- or *only* empty lines were below (cursor at the last line)
  if i ~= cur and i ~= eob then
    return
  end

  -- then: also expand the selection to the empty lines above
  vim.cmd [[normal! o]]
  local i = vim.fn.line "."
  while i > 1 and vim.fn.getline(i - 1):match "^%s*$" ~= nil do
    i = i - 1
  end
  vim.api.nvim_win_set_cursor(0, { i, 0 })
  vim.cmd [[normal! o]]
end

return M
