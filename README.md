# kai-obsidian.nvim

A Neovim plugin that extends [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) with opinionated workflows for note creation, weekly notes, and vault navigation.

## Features

- **Note creation** — interactive flow with directory selection, template picking, and optional timestamp suffixing
- **Weekly notes** — create weekly notes from a template, automatically carrying over unchecked tasks from the previous week
- **Scratch notes** — quick access to a persistent scratch note in your vault
- **Image pasting** — paste images with paths scoped to the current note's UID

## Requirements

- Neovim >= 0.9
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) (must be configured with at least one workspace)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) (for weekly note listing)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "kev-cao/kai-obsidian.nvim",
  dependencies = {
    "obsidian-nvim/obsidian.nvim",
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
  },
  opts = {},
},
```

You still need to configure `obsidian.nvim` separately in your own plugin specs — this plugin does not manage the obsidian.nvim setup for you.

## Configuration

All options and their defaults:

```lua
require("kai-obsidian").setup({
  -- Weekly note settings
  weekly = {
    -- Template name used when creating a new weekly note
    template = "weekly-tmpl",
    -- Filename prefix for weekly notes. The year/week suffix (e.g.
    -- "2026w22") is appended to this prefix.
    filename_prefix = "weekly-",
    -- Heading names whose unchecked tasks carry over to the next week.
    copyover_sections = { "Tasks", "Backlog" },
  },

  -- Maps template names (without .md) to vault subdirectories. Unmapped
  -- templates default to the vault root. Set a template to vim.NIL to
  -- prompt the user for a directory instead.
  template_output_dirs = {
    ["weekly-tmpl"] = "weeklies",
    ["people-tmpl"] = "people",
    ["project-tmpl"] = "projects",
    ["category-tmpl"] = "categories",
    -- ["some-tmpl"] = vim.NIL,  -- prompts for directory
  },

  -- Maps template names (without .md) to timestamp behavior:
  -- "query" prompts the user, "auto" always suffixes.
  timestamp_templates = {
    ["meeting-tmpl"] = "query",
  },

  -- Keymap configuration. Keys are named so individual entries can be
  -- overridden or disabled (set to false) via opts.
  keymaps = {
    -- Which-key groups
    groups = {
      { "<leader>o", group = "Obsidian", icon = { icon = "󱓧", color = "green" } },
      { "<leader>ot", group = "Weekly Notes", icon = { icon = "", color = "green" } },
    },
    -- Global keymaps
    keys = {
      open_scratch = { "<leader>os", ... },
      new_note     = { "<leader>on", ... },
      weekly       = { "<leader>ott", ... },
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
| `<leader>ott` | Go to this week's note (creates if needed) |
| `<leader>otl` | List all weekly notes |

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
local notes = require("kai-obsidian.notes")
notes.create_new_note()
notes.open_scratch()
notes.normalize_note_title("My Note Title")
notes.image_path("screenshot.png")

-- Weekly notes
local weekly = require("kai-obsidian.weekly")
weekly.goto_or_create_weekly()
weekly.list_weekly()

-- Date utilities
local date = require("kai-obsidian.date")
date.week_to_date(2026, 16, "%Y-%m-%d")

-- Plugin config and vault path
local plugin = require("kai-obsidian")
plugin.vault_path()  -- returns vault path from obsidian.nvim
plugin.config        -- current config table
```
