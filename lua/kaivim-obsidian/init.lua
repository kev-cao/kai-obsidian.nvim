--- @module "kaivim-obsidian"
--- A lazy.nvim plugin for managing Obsidian notes with opinionated workflows
--- for note creation, weekly todos, and vault navigation.

local M = {}

--- @class KaiVimObsidianConfig
--- @field vault_path string Path to the Obsidian vault
--- @field weekly_todo KaiVimObsidianWeeklyTodoConfig
--- @field templates KaiVimObsidianTemplateConfig
--- @field frontmatter KaiVimObsidianFrontmatterConfig
--- @field keymaps KaiVimObsidianKeymapConfig

--- @class KaiVimObsidianWeeklyTodoConfig
--- @field dir string Subdirectory within the vault for weekly todos
--- @field template string Template name for new weekly todos
--- @field copyover_sections table<string, string> Heading text → key for sections whose unchecked tasks carry over

--- @class KaiVimObsidianTemplateConfig
--- @field folder string Subdirectory within the vault for templates
--- @field date_format string
--- @field time_format string

--- @class KaiVimObsidianFrontmatterConfig
--- @field enabled (fun(path: string): boolean)|boolean

--- @class KaiVimObsidianKeymapConfig
--- @field groups table[] Which-key groups for obsidian
--- @field keys table[] Global keymaps
--- @field bufkeys table[] Buffer-local keymaps for obsidian markdown files

--- @type KaiVimObsidianConfig
M.config = {
  vault_path = "~/Documents/obsidian",
  weekly_todo = {
    dir = "todos",
    template = "weekly-todo-tmpl",
    copyover_sections = {
      Tasks = "tasks",
      Backlog = "backlog",
    },
  },
  templates = {
    folder = "nvim-templates",
    date_format = "%Y-%m-%d",
    time_format = "%H:%M",
  },
  frontmatter = {
    enabled = function(path)
      return not string.match(path, "%.claude/")
    end,
  },
  keymaps = {
    groups = {
      { "<leader>o", group = "Obsidian", icon = { icon = "󱓧", color = "green" } },
      { "<leader>ot", group = "Weekly Todos", icon = { icon = "", color = "green" } },
    },
    keys = {},
    bufkeys = {},
  },
}

--- Returns the canonical expanded path to the Obsidian vault.
--- @return string
function M.vault_path()
  return vim.fn.expand(M.config.vault_path)
end

--- @param opts? KaiVimObsidianConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local default_keymaps = require("kaivim-obsidian.keymaps")

  if vim.tbl_isempty(M.config.keymaps.keys) then
    M.config.keymaps.keys = default_keymaps.default_keys()
  end

  if vim.tbl_isempty(M.config.keymaps.bufkeys) then
    M.config.keymaps.bufkeys = default_keymaps.default_bufkeys()
  end

  -- Set up which-key groups if which-key is available
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add(M.config.keymaps.groups)
  end

  -- Register global keymaps
  for _, map in ipairs(M.config.keymaps.keys) do
    vim.keymap.set(map.mode, map[1], map[2], {
      desc = map.desc,
    })
  end

  -- Set up buffer-local keymaps for obsidian vault markdown files
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = M.vault_path() .. "/*.md",
    group = vim.api.nvim_create_augroup("kaivim_obsidian", { clear = true }),
    callback = function()
      local curr_file = vim.fn.expand("%:p")
      -- Skip claude prompt buffers
      if curr_file:match("claude%-prompt%-") then
        return
      end

      vim.cmd("setlocal textwidth=100")

      if wk_ok then
        local func = require("kaivim-obsidian.func")
        wk.add(func.make_buflocal(M.config.keymaps.bufkeys))
      else
        for _, map in ipairs(M.config.keymaps.bufkeys) do
          vim.keymap.set(map.mode, map[1], map[2], {
            buffer = 0,
            desc = map.desc,
          })
        end
      end
    end,
  })
end

return M
