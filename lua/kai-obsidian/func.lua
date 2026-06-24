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

--- Returns the path to the scratch note in the Obsidian vault based on the
--- plugin config.
--- @param config KaiObsidianConfig The plugin configuration.
--- @return string The path to the scratch note, relative to vault root.
function M.get_scratch_path(config)
  if type(config.scratch.path) == "function" then
    return config.scratch.path()
  else
    return config.scratch.path
  end
end

--- Returns the path to the backlog note in the Obsidian vault based on the
--- plugin config.
--- @param config KaiObsidianConfig The plugin configuration.
--- @return string The path to the backlog note, relative to vault root.
function M.get_backlog_path(config)
  if type(config.backlog.path) == "function" then
    return config.backlog.path()
  else
    return config.backlog.path
  end
end

return M
