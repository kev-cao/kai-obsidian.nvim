--- @module "kai-obsidian.func"
--- Small utility functions used by the plugin.

local M = {}

--- Creates a new which-key spec with the buffer option set to true.
--- @param specs table A list of which-key specs.
--- @return table A new list of which-key specs with the buffer option set to true.
function M.make_buflocal(specs)
  local ret = {}
  for _, spec in ipairs(specs) do
    spec = vim.deepcopy(spec)
    spec.buffer = true
    table.insert(ret, spec)
  end
  return ret
end

return M
