--- @module "kaivim-obsidian.date"
--- Date and time utility functions.

local M = {}

--- Converts an ISO week date (year and week number) to a standard date string.
--- @param year number The ISO week-numbering year.
--- @param week number The ISO week number (1-53).
--- @param fmt string The format string for os.date (e.g., "%Y-%m-%d").
--- @return string The corresponding date string formatted according to fmt.
function M.week_to_date(year, week, fmt)
  local jan4 = os.time({ year = year, month = 1, day = 4, hour = 12, min = 0, sec = 0 })
  local jan4_table = os.date("*t", jan4)
  local weekday_jan4 = jan4_table.wday
  if weekday_jan4 == 1 then
    weekday_jan4 = 8
  end
  local days_to_monday = weekday_jan4 - 2
  local week1_monday_timestamp = jan4 - (days_to_monday * 86400)
  local target_monday_timestamp = week1_monday_timestamp + ((week - 1) * 7 * 86400)
  return tostring(os.date(fmt, target_monday_timestamp))
end

return M
