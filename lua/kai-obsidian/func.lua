--- @module "kai-obsidian.func"
--- Small utility functions used by the plugin.

local M = {}

--- Creates a new which-key spec with the buffer option set.
--- @param specs table A list of which-key specs.
--- @param bufnr? number Buffer number (defaults to current buffer).
--- @return table A new list of which-key specs with the buffer option set.
function M.make_buflocal(specs, bufnr)
  local ret = {}
  for _, spec in ipairs(specs) do
    spec = vim.deepcopy(spec)
    spec.buffer = bufnr or true
    table.insert(ret, spec)
  end
  return ret
end

return M
