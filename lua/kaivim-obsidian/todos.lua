--- @module "kaivim-obsidian.todos"
--- Weekly todo management for Obsidian vaults.

local M = {}

--- @return table The plugin config
local function cfg()
  return require("kaivim-obsidian").config
end

--- @return string The expanded vault path
local function vault_path()
  return require("kaivim-obsidian").vault_path()
end

--- Returns the heading level of a line, or nil if not a heading.
--- @param line string
--- @return number|nil
local function heading_level(line)
  local hashes = string.match(line, "^(#+)%s")
  return hashes and #hashes or nil
end

--- Returns the subdirectory for weekly todos, resolved from template_output_dirs
--- using the weekly todo template name.
--- @return string
local function todo_dir()
  local config = cfg()
  return config.template_output_dirs[config.weekly_todo.template] or "todos"
end

--- Computes the file path for the weekly todo note for a given date.
--- @param date string The date in "YYYY-MM-DD" format.
--- @return string The file path for the weekly todo note.
local function weekly_todo_path(date)
  local year, month, day = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  year = tonumber(year)
  month = tonumber(month)
  day = tonumber(day)
  local time = os.time({ year = year, month = month, day = day })
  local week = tostring(os.date("%Yw%V", time))
  local todo_filename = "todo-weekly-" .. week
  return vault_path() .. "/" .. todo_dir() .. "/" .. todo_filename .. ".md"
end

--- Computes the file path for last week's todo note.
--- @return string
local function last_week_todo_path()
  local one_week_ago = os.time() - (7 * 24 * 60 * 60)
  local week = tostring(os.date("%Yw%V", one_week_ago))
  local todo_filename = "todo-weekly-" .. week
  return vault_path() .. "/" .. todo_dir() .. "/" .. todo_filename .. ".md"
end

--- Builds a set from the copyover_sections array for O(1) lookup.
--- @return table<string, boolean>
local function copyover_set()
  local sections = cfg().weekly_todo.copyover_sections
  local set = {}
  for _, name in ipairs(sections) do
    set[name] = true
  end
  return set
end

--- Extracts unchecked tasks from copyover sections of a todo file.
--- @param file_path string The path to the todo file.
--- @return table<string, string[]> A map from heading name to unchecked task lines.
local function extract_unchecked_tasks(file_path)
  local sections = copyover_set()
  local result = {}
  for name in pairs(sections) do
    result[name] = {}
  end
  if vim.fn.filereadable(file_path) ~= 1 then
    return result
  end
  local lines = vim.fn.readfile(file_path)
  local current_section = nil
  local section_level = nil
  local pending_headers = {}
  local in_unchecked = false
  for _, line in ipairs(lines) do
    local level = heading_level(line)
    if level then
      in_unchecked = false
      local heading_text = string.match(line, "^#+%s+(.+)$")
      if heading_text and sections[heading_text] then
        current_section = heading_text
        section_level = level
        pending_headers = {}
      elseif section_level and level <= section_level then
        current_section = nil
        section_level = nil
        pending_headers = {}
      elseif current_section then
        table.insert(pending_headers, line)
      end
    elseif current_section and string.match(line, "^%s*%- %[ %]") then
      for _, header in ipairs(pending_headers) do
        table.insert(result[current_section], header)
      end
      pending_headers = {}
      table.insert(result[current_section], line)
      in_unchecked = true
    elseif current_section and string.match(line, "^%s*%-") then
      in_unchecked = false
    elseif current_section and in_unchecked and line ~= "" then
      table.insert(result[current_section], line)
    else
      in_unchecked = false
    end
  end
  return result
end

--- Injects unchecked tasks from last week into the current todo file.
--- @param todo_path string The path to the current todo file.
--- @param tasks table<string, string[]> A map from heading name to unchecked task lines.
local function inject_unchecked_tasks(todo_path, tasks)
  local sections = copyover_set()
  local has_any = false
  for _, items in pairs(tasks) do
    if #items > 0 then
      has_any = true
      break
    end
  end
  if not has_any then
    return
  end
  local lines = vim.fn.readfile(todo_path)

  local stripped = {}
  local current_section = nil
  local section_level = nil
  for _, line in ipairs(lines) do
    local level = heading_level(line)
    if level then
      local heading_text = string.match(line, "^#+%s+(.+)$")
      if heading_text and sections[heading_text] then
        current_section = heading_text
        section_level = level
      elseif section_level and level <= section_level then
        current_section = nil
        section_level = nil
      end
    end
    local is_placeholder = string.match(line, "^%- %[ %]%s*$")
    local strip = is_placeholder and current_section and #tasks[current_section] > 0
    if not strip then
      table.insert(stripped, line)
    end
  end

  local new_lines = {}
  local injected = false
  for _, line in ipairs(stripped) do
    table.insert(new_lines, line)
    local heading_text = string.match(line, "^#+%s+(.+)$")
    if heading_text and sections[heading_text] and #tasks[heading_text] > 0 then
      for _, task in ipairs(tasks[heading_text]) do
        table.insert(new_lines, task)
      end
      injected = true
    end
  end

  if injected then
    vim.fn.writefile(new_lines, todo_path)
  end
end

--- Opens the weekly todo note for the current week, creating it if it does not
--- exist. If creating a new todo, copies unchecked tasks from last week's todo.
function M.goto_or_create_weekly()
  local obsidian = require("obsidian")
  local config = cfg()
  local todo_filename = "todo-weekly-" .. os.date("%Yw%V")
  local dir = vault_path() .. "/" .. todo_dir() .. "/"
  local todo_path = dir .. todo_filename .. ".md"
  if vim.fn.filereadable(todo_path) == 1 then
    local note = obsidian.Note.from_file(todo_path)
    note:open({ sync = false })
  else
    local last_week_path = last_week_todo_path()
    local unchecked = extract_unchecked_tasks(last_week_path)

    local note = obsidian.Note.create({
      id = todo_filename,
      title = todo_filename,
      verbatim = true,
      dir = dir,
      should_write = true,
      insert_frontmatter = false,
      template = config.weekly_todo.template,
    })

    vim.schedule(function()
      inject_unchecked_tasks(todo_path, unchecked)
      vim.cmd("checktime")
    end)

    note:open({ sync = false })
  end
end

--- Lists all weekly todos in a Fzf picker.
function M.list_weekly()
  local date_util = require("kaivim-obsidian.date")
  local obsidian = require("obsidian")
  local todos_path = vault_path() .. "/" .. todo_dir() .. "/"
  local dates = {}
  local date_to_file = {}
  for _, file in ipairs(vim.fn.globpath(
    todos_path, "todo-weekly-*.md", false, true
  )) do
    local filename = vim.fn.fnamemodify(file, ":t:r")
    local year_week = filename:sub(#"todo-weekly-" + 1)
    local year, week = string.match(year_week, "^(%d%d%d%d)w(%d%d)$")
    year = tonumber(year)
    week = tonumber(week)
    local date = date_util.week_to_date(year, week, "%Y-%m-%d")
    table.insert(dates, 0, date)
    date_to_file[date] = file
  end

  local fzf = require("fzf-lua")
  local builtin_previewer = require("fzf-lua.previewer.builtin")
  local todo_previewer = builtin_previewer.buffer_or_file:extend()
  function todo_previewer:new(o, opts, fzf_win)
    todo_previewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, todo_previewer)
    return self
  end
  function todo_previewer:parse_entry(entry)
    return {
      path = weekly_todo_path(entry),
      line = 1,
      col = 1,
    }
  end

  fzf.fzf_exec(dates, {
    prompt = "Select Weekly Todo Date>",
    previewer = todo_previewer,
    fzf_opts = {
      ["--preview-window"] = "nohidden,down,60%",
    },
    actions = {
      ["default"] = function(selected)
        local date = selected[1]
        local note = obsidian.Note.from_file(date_to_file[date])
        note:open({ sync = false })
      end,
      ["ctrl-v"] = function(selected)
        local date = selected[1]
        local note = obsidian.Note.from_file(date_to_file[date])
        note:open({ sync = false, open_strategy = "vsplit" })
      end,
      ["ctrl-s"] = function(selected)
        local date = selected[1]
        local note = obsidian.Note.from_file(date_to_file[date])
        note:open({ sync = false, open_strategy = "hsplit" })
      end,
    },
  })
end

return M
