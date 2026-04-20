# kaivim-obsidian

A Neovim plugin that extends [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) with opinionated workflows for note creation, weekly todos, and vault navigation.

## Features

- **Note creation** — interactive flow with directory selection, template picking, and optional timestamp suffixing
- **Weekly todos** — create weekly todo notes from a template, automatically carrying over unchecked tasks from the previous week
- **Scratch notes** — quick access to a persistent scratch note in your vault
- **Image pasting** — paste images with paths scoped to the current note's UID

## Requirements

- Neovim >= 0.9
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) (for weekly todo listing)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "kev-cao/kaivim-obsidian",
  dependencies = {
    "obsidian-nvim/obsidian.nvim",
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
  },
  opts = {
    vault_path = "~/Documents/obsidian",
  },
},
```

You still need to configure `obsidian.nvim` separately in your own plugin specs — this plugin does not manage the obsidian.nvim setup for you.

## Configuration

All options and their defaults:

```lua
require("kaivim-obsidian").setup({
  -- Path to your Obsidian vault
  vault_path = "~/Documents/obsidian",

  -- Weekly todo settings
  weekly_todo = {
    -- Subdirectory within the vault for weekly todo files
    dir = "todos",
    -- Template name used when creating a new weekly todo
    template = "weekly-todo-tmpl",
    -- Heading names whose unchecked tasks carry over to the next week.
    -- Keys are the heading text, values are internal keys.
    copyover_sections = {
      Tasks = "tasks",
      Backlog = "backlog",
    },
  },

  -- Template settings (passed through to obsidian.nvim)
  templates = {
    folder = "nvim-templates",
    date_format = "%Y-%m-%d",
    time_format = "%H:%M",
  },

  -- Frontmatter settings (passed through to obsidian.nvim)
  frontmatter = {
    -- Function or boolean controlling whether frontmatter is added to notes
    enabled = function(path)
      return not string.match(path, "%.claude/")
    end,
  },

  -- Keymap configuration. Keys are named so individual entries can be
  -- overridden or disabled (set to false) via opts.
  keymaps = {
    -- Which-key groups
    groups = {
      { "<leader>o", group = "Obsidian", icon = { icon = "󱓧", color = "green" } },
      { "<leader>ot", group = "Weekly Todos", icon = { icon = "", color = "green" } },
    },
    -- Global keymaps
    keys = {
      open_scratch = { "<leader>os", ... },
      new_note     = { "<leader>on", ... },
      weekly_todo  = { "<leader>ott", ... },
      list_weekly  = { "<leader>otl", ... },
    },
    -- Buffer-local keymaps for vault markdown files
    bufkeys = {
      paste_img = { "<localleader>pi", ... },
    },
  },
})
```

## Default Keymaps

### Global

| Key | Description |
|-----|-------------|
| `<leader>os` | Open scratch note |
| `<leader>on` | Create a new note (interactive) |
| `<leader>ott` | Go to this week's todo (creates if needed) |
| `<leader>otl` | List all weekly todos |

### Buffer-local (vault markdown files)

| Key | Description |
|-----|-------------|
| `<localleader>pi` | Paste image from clipboard |

To override a specific keymap, provide an entry with the same name in your
opts. To disable a keymap, set it to `false`:

```lua
opts = {
  keymaps = {
    keys = {
      open_scratch = { "<leader>ns", ... },  -- remap
      list_weekly = false,                    -- disable
    },
  },
},
```

## API

The plugin exposes modules you can use directly:

```lua
-- Note utilities
local notes = require("kaivim-obsidian.notes")
notes.create_new_note()
notes.open_scratch()
notes.note_id()
notes.normalize_note_title("My Note Title")
notes.image_path("screenshot.png")

-- Weekly todos
local todos = require("kaivim-obsidian.todos")
todos.goto_or_create_weekly()
todos.list_weekly()

-- Date utilities
local date = require("kaivim-obsidian.date")
date.week_to_date(2026, 16, "%Y-%m-%d")

-- Plugin config and vault path
local plugin = require("kaivim-obsidian")
plugin.vault_path()  -- returns expanded path
plugin.config        -- current config table
```
