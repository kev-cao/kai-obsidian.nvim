--- @module "kai-obsidian"
--- A lazy.nvim plugin for managing Obsidian notes with opinionated workflows
--- for note creation, weekly notes, and vault navigation.

local M = {}

--- @class KaiObsidianConfig
--- @field obsidian table Options passed through to obsidian.nvim's setup(). Merged into defaults via vim.tbl_deep_extend("force", ...).
--- @field weekly KaiObsidianWeeklyConfig
--- @field template_output_dirs table<string, string|userdata> Maps template names (without .md) to vault subdirectories. Set to vim.NIL to prompt for directory.
--- @field timestamp_templates table<string, "query"|"auto"> Maps template names (without .md) to timestamp behavior: "query" prompts the user, "auto" always suffixes.
--- @field keymaps KaiObsidianKeymapConfig

--- @class KaiObsidianWeeklyConfig
--- @field template string Template name for new weekly notes
--- @field filename_prefix string Filename prefix for weekly notes (the year/week suffix is appended)
--- @field copyover_sections string[] Heading names whose unchecked tasks carry over to the next week

--- @class KaiObsidianKeymapConfig
--- @field groups table[] Which-key groups for obsidian
--- @field keys table<string, table|false> Global keymaps (set to false to disable)
--- @field bufkeys table<string, table|false> Buffer-local keymaps for obsidian markdown files (set to false to disable)

--- @type KaiObsidianConfig
M.config = {
  obsidian = {
    legacy_commands = false,
    workspaces = {
      { name = "obsidian", path = vim.fn.expand("~/Documents/obsidian") },
    },
    picker = {
      name = "fzf-lua",
      note_mappings = { new = "<C-n>", insert_link = "<C-l>" },
    },
    attachments = { folder = "attachments" },
    note_id_func = nil,
    frontmatter = {
      enabled = function(path) return not string.match(path, "%claude/") end,
      func = function(note)
        local out = {
          uid = require("kai-obsidian.notes").note_id(),
          aliases = note.aliases,
          categories = {},
        }
        if note.tags ~= nil then out.tags = note.tags end
        if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
          for k, v in pairs(note.metadata) do
            if k ~= "uid" or (v ~= nil and v ~= "" and v ~= vim.NIL) then
              out[k] = v
            end
          end
        end
        return out
      end,
      sort = {
        "uid",
        "aliases",
        "created_at",
        "week",
        "people",
        "categories",
        "tags",
      }
    },
    templates = {
      folder = "nvim-templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {
        id = function() return require("kai-obsidian.notes").note_id() end,
        today_week = function() return os.date("%Y-W%V") end,
        week_start_date = function()
          local current_time = os.time()
          local day_of_week_iso = tonumber(os.date("%u", current_time))
          local days_to_subtract = day_of_week_iso - 1
          local seconds_in_day = 60 * 60 * 24
          local first_day_time = current_time - (days_to_subtract * seconds_in_day)
          return os.date("%B %-e, %Y", first_day_time)
        end,
        day = function() return os.date("%A, %B %-e, %Y") end,
      },
    },
    daily_notes = {
      folder = "dailies",
      date_format = "[daily-]YYYY-MM-DD",
      default_tags = {},
      template = "daily-tmpl",
    },
    completion = { min_chars = 0 },
    checkbox = {
      order = { " ", "x", "!", ">", "~" },
    },
  },
  weekly = {
    template = "weekly-tmpl",
    filename_prefix = "weekly-",
    copyover_sections = { "Tasks", "Backlog" },
  },
  template_output_dirs = {
    ["weekly-tmpl"] = "weeklies",
    ["person-tmpl"] = "people",
    ["project-tmpl"] = "projects",
    ["category-tmpl"] = "categories",
  },
  timestamp_templates = {
    ["meeting-tmpl"] = "query",
  },
  keymaps = {
    groups = {
      { "<leader>o", group = "Obsidian", icon = { icon = "󱓧", color = "green" } },
      { "<leader>ot", group = "Weekly Notes", icon = { icon = "", color = "green" } },
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
      weekly = {
        "<leader>oww",
        function() require("kai-obsidian.weekly").goto_or_create_weekly() end,
        mode = "n",
        desc = "Go to weekly note",
      },
      list_weekly = {
        "<leader>owl",
        function() require("kai-obsidian.weekly").list_weekly() end,
        mode = "n",
        desc = "List weekly notes",
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

  require("obsidian").setup(M.config.obsidian)

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
  local vault = M.vault_path()

  local function apply_bufkeys(bufnr)
    for _, map in pairs(M.config.keymaps.bufkeys) do
      if map then
        if wk_ok then
          local func = require("kai-obsidian.func")
          wk.add(func.make_buflocal({ map }, bufnr))
        else
          vim.keymap.set(map.mode, map[1], map[2], {
            buffer = bufnr,
            desc = map.desc,
          })
        end
      end
    end
  end

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { vault .. "/*.md", vault .. "/**/*.md" },
    group = vim.api.nvim_create_augroup("kai_obsidian", { clear = true }),
    callback = function(ev)
      apply_bufkeys(ev.buf)
    end,
  })

  -- Apply to any already-open vault buffers (setup may run after BufRead)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if vim.api.nvim_buf_is_loaded(bufnr) and name:find(vault, 1, true) == 1 and name:match("%.md$") then
      apply_bufkeys(bufnr)
    end
  end
end

return M
