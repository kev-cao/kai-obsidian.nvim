--- @module "kaivim-obsidian.keymaps"
--- Default keymaps for kaivim-obsidian.
--- Only includes keymaps that call this plugin's own functions.
--- Keymaps for native obsidian.nvim commands belong in the consuming config.

local M = {}

function M.default_keys()
  local notes = require("kaivim-obsidian.notes")
  local todos = require("kaivim-obsidian.todos")
  return {
    {
      "<leader>os",
      notes.open_scratch,
      mode = "n",
      desc = "Open Obsidian scratchpad",
    },
    {
      "<leader>on",
      notes.create_new_note,
      mode = "n",
      desc = "Create a new Obsidian note",
    },
    {
      "<leader>ott",
      todos.goto_or_create_weekly,
      mode = "n",
      desc = "Go to weekly todo",
    },
    {
      "<leader>otl",
      todos.list_weekly,
      mode = "n",
      desc = "List weekly todos",
    },
  }
end

function M.default_bufkeys()
  local notes = require("kaivim-obsidian.notes")
  return {
    {
      "<localleader>pi",
      function()
        vim.ui.input({ prompt = "Image name: " }, function(input)
          if input then
            vim.cmd("Obsidian paste_img " .. notes.image_path(input))
          end
        end)
      end,
      mode = "n",
      desc = "Paste image from clipboard into Obsidian vault",
    },
  }
end

return M
