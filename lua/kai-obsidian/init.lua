--- @module "kai-obsidian"
--- A lazy.nvim plugin for managing Obsidian notes with opinionated workflows
--- for note creation, weekly todos, and vault navigation.

local M = {}

--- @class KaiObsidianConfig
--- @field weekly_todo KaiObsidianWeeklyTodoConfig
--- @field template_output_dirs table<string, string|userdata> Maps template names (without .md) to vault subdirectories. Set to vim.NIL to prompt for directory.
--- @field timestamp_templates table<string, "query"|"auto"> Maps template names (without .md) to timestamp behavior: "query" prompts the user, "auto" always suffixes.
--- @field keymaps KaiObsidianKeymapConfig

--- @class KaiObsidianWeeklyTodoConfig
--- @field template string Template name for new weekly todos
--- @field copyover_sections string[] Heading names whose unchecked tasks carry over to the next week

--- @class KaiObsidianKeymapConfig
--- @field groups table[] Which-key groups for obsidian
--- @field keys table<string, table|false> Global keymaps (set to false to disable)
--- @field bufkeys table<string, table|false> Buffer-local keymaps for obsidian markdown files (set to false to disable)

--- @type KaiObsidianConfig
M.config = {
  weekly_todo = {
    template = "weekly-todo-tmpl",
    copyover_sections = { "Tasks", "Backlog" },
  },
  template_output_dirs = {
    ["weekly-todo-tmpl"] = "todos",
    ["people-tmpl"] = "people",
    ["project-tmpl"] = "projects",
    ["category-tmpl"] = "categories",
  },
  timestamp_templates = {
    ["meeting-tmpl"] = "query",
  },
  keymaps = {
    groups = {
      { "<leader>o", group = "Obsidian", icon = { icon = "󱓧", color = "green" } },
      { "<leader>ot", group = "Weekly Todos", icon = { icon = "", color = "green" } },
    },
    keys = {
      open_scratch = {
        "<leader>os",
        function() require("kai-obsidian.notes").open_scratch() end,
        mode = "n",
        desc = "Open Obsidian scratchpad",
      },
      new_note = {
        "<leader>on",
        function() require("kai-obsidian.notes").create_new_note() end,
        mode = "n",
        desc = "Create a new Obsidian note",
      },
      weekly_todo = {
        "<leader>ott",
        function() require("kai-obsidian.todos").goto_or_create_weekly() end,
        mode = "n",
        desc = "Go to weekly todo",
      },
      list_weekly = {
        "<leader>otl",
        function() require("kai-obsidian.todos").list_weekly() end,
        mode = "n",
        desc = "List weekly todos",
      },
    },
    bufkeys = {
      paste_img = {
        "<localleader>pi",
        function()
          vim.ui.input({ prompt = "Image name: " }, function(input)
            if input then
              local notes = require("kai-obsidian.notes")
              vim.cmd("Obsidian paste_img " .. notes.image_path(input))
            end
          end)
        end,
        mode = "n",
        desc = "Paste image from clipboard into Obsidian vault",
      },
    },
  },
}

--- Returns the canonical expanded path to the Obsidian vault, read from
--- obsidian.nvim's global state.
--- @return string
function M.vault_path()
  return tostring(Obsidian.dir)
end

--- @param opts? KaiObsidianConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Set up which-key groups if which-key is available
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add(M.config.keymaps.groups)
  end

  -- Register global keymaps
  for _, map in pairs(M.config.keymaps.keys) do
    if map then
      vim.keymap.set(map.mode, map[1], map[2], {
        desc = map.desc,
      })
    end
  end

  -- Set up buffer-local keymaps for obsidian vault markdown files
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = M.vault_path() .. "/**/*.md",
    group = vim.api.nvim_create_augroup("kai_obsidian", { clear = true }),
    callback = function()
      for _, map in pairs(M.config.keymaps.bufkeys) do
        if map then
          if wk_ok then
            local func = require("kai-obsidian.func")
            wk.add(func.make_buflocal({ map }))
          else
            vim.keymap.set(map.mode, map[1], map[2], {
              buffer = 0,
              desc = map.desc,
            })
          end
        end
      end
    end,
  })
end

return M
