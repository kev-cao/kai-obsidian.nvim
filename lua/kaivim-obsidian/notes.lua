--- @module "kaivim-obsidian.notes"
--- Note creation, directory querying, and vault navigation utilities.

local M = {}

--- Recursively query the user for the directory they want to put a new note in.
--- @param dir string The directory to query.
--- @param cb fun(dir: string|nil) Callback function to call with the selected directory.
local function query_directory(dir, cb)
  local fs = require("plenary.scandir")
  local subdirs = {}
  for _, path in ipairs(fs.scan_dir(dir, { depth = 1, only_dirs = true })) do
    if path ~= dir then
      local subdir = path:sub(#dir + 2)
      table.insert(subdirs, subdir)
    end
  end

  if #subdirs == 0 then
    cb(dir)
    return
  end

  local choices = vim.list_extend({ "Choose current dir" }, subdirs)
  vim.ui.select(choices, {
    prompt = "Select subdirectory for new note (or choose current dir):",
  }, function(choice)
    if choice == nil then
      cb(nil)
    elseif choice == "Choose current dir" then
      cb(dir)
    else
      query_directory(dir .. "/" .. choice, cb)
    end
  end)
end

--- Prompts the user to select a template for a new note.
--- @param cb fun(template: string|nil) Callback function to call with the
--- selected template. Empty string is returned if no template, nil if aborted.
local function query_template(cb)
  local obsidian = require("obsidian")
  local fs = require("plenary.scandir")
  local template_dir = tostring(obsidian.api.templates_dir())
  local templates = {}
  for _, path in ipairs(fs.scan_dir(template_dir)) do
    local template = path:sub(#template_dir + 2)
    if not vim.endswith(template, ".md") then
      goto continue
    end
    template = template:sub(1, #template - 3)
    table.insert(templates, template)
    ::continue::
  end
  if #templates == 0 then
    cb(nil)
    return
  end

  local choices = vim.list_extend({ "No template" }, templates)
  vim.ui.select(choices, {
    prompt = "Select template for new note:",
  }, function(choice)
    if choice == nil then
      cb(nil)
    elseif choice == "No template" then
      cb("")
    else
      cb(choice)
    end
  end)
end

--- Normalizes an Obsidian note title to be a valid file name.
--- @param title string|nil The title of the note.
--- @return string The normalized note title.
function M.normalize_note_title(title)
  if title == nil then
    title = ""
    for _ = 1, 4 do
      title = title .. string.char(math.random(65, 90))
    end
  else
    title = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
  end
  return title
end

--- Generates an ID for an Obsidian note.
--- @return string The generated note ID.
function M.note_id()
  local time = os.time()
  local hex_time = string.format("id-%08x", time)
  return hex_time
end

--- Returns the image path for pasting an image into the current Obsidian note.
--- Prefixes the image name with the note's uid hex (without "id-" prefix) as a
--- subdirectory. If the note has no uid, returns the image name as-is.
--- @param image_name string The image file name.
--- @return string The image path relative to the attachments folder.
function M.image_path(image_name)
  local lines = vim.api.nvim_buf_get_lines(0, 0, 30, false)
  local in_frontmatter = false
  for _, line in ipairs(lines) do
    if line == "---" then
      if in_frontmatter then
        break
      end
      in_frontmatter = true
    elseif in_frontmatter then
      local uid_hex = line:match("^uid:%s*id%-(%x+)%s*$")
      if uid_hex then
        return uid_hex .. "/" .. image_name
      end
    end
  end
  return image_name
end

--- Checks if a note title is already formatted with a timestamp.
--- @param title string The title of the note.
--- @return boolean
function M.note_title_has_ts(title)
  if title == nil then
    return false
  end
  local pattern = "^[a-z0-9%-]+%-"
  for _ = 1, 14 do
    pattern = pattern .. "%d"
  end
  pattern = pattern .. "$"
  return string.match(title, pattern) ~= nil
end

--- Suffixes a note title with a timestamp to ensure uniqueness.
--- @param title string The title of the note.
--- @return string The title suffixed with a timestamp if it was not already.
function M.suffix_title_ts(title)
  if M.note_title_has_ts(title) then
    return title
  end
  title = M.normalize_note_title(title)
  local ts = os.date("%Y%m%d%H%M%S", os.time())
  return title .. "-" .. tostring(ts)
end

--- Generates default aliases for an Obsidian note based on its title.
--- @param title string The title of the note.
--- @return table A table of default aliases.
function M.default_note_aliases(title)
  local aliases = {}
  local normalized = M.normalize_note_title(title)
  if normalized ~= title then
    table.insert(aliases, title)
  end
  return aliases
end

--- Creates a new Obsidian note, prompting the user for the directory and title.
--- @param opts? table Options for creating the note.
function M.create_new_note(opts)
  local plugin = require("kaivim-obsidian")
  local obsidian = require("obsidian")
  local obsidian_path = plugin.vault_path()
  local abort = function()
    vim.notify("Aborted note creation.", vim.log.levels.INFO)
  end

  local async = require("plenary.async")
  local query_dir_async = async.wrap(query_directory, 2)
  local query_template_async = async.wrap(query_template, 1)

  async.void(function()
    local template, _ = query_template_async()
    if template == nil then
      abort()
      return
    elseif template == "" then
      template = nil
    end
    local dir, _ = query_dir_async(obsidian_path)
    if dir == nil then
      abort()
      return
    end
    local title = nil
    vim.ui.input({ prompt = "Note name: " }, function(input)
      if input then
        title = input
      end
    end)
    if title == nil then
      abort()
      return
    end
    local normalized_title = M.normalize_note_title(title)

    local choice = vim.fn.confirm("Add timestamp to title?", "&Yes\n&No\n&Cancel", 3)
    if choice == 3 then
      abort()
      return
    elseif choice == 1 then
      normalized_title = M.suffix_title_ts(normalized_title)
    end

    local create_opts = {
      id = normalized_title,
      title = normalized_title,
      verbatim = true,
      dir = dir,
      template = template,
      insert_frontmatter = template == nil,
      aliases = M.default_note_aliases(title),
      should_write = true,
    }
    vim.tbl_extend("keep", create_opts, opts or {})
    local note = obsidian.Note.create(create_opts)
    note:open({ sync = false })
  end)()
end

--- Opens the scratch note in the Obsidian vault.
function M.open_scratch()
  local plugin = require("kaivim-obsidian")
  local obsidian = require("obsidian")
  local vault_path = plugin.vault_path()
  local scratch_path = vault_path .. "/scratch.md"
  if vim.fn.filereadable(scratch_path) == 1 then
    local note = obsidian.Note.from_file(scratch_path)
    note:open({ sync = false })
  else
    local note = obsidian.Note.create({
      id = "scratch",
      title = "scratch",
      verbatim = true,
      dir = vault_path,
      should_write = true,
    })
    note:open({ sync = false })
  end
end

return M
