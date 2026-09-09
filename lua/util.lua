local M = {}

function M.alpha(color, level)
  local rgb = color:sub(5)
  local prefix = ({ [100] = "0xFF", [75] = "0xBF", [50] = "0x80", [25] = "0x40" })[level]
  return prefix .. rgb
end

function M.trim(text)
  return (text:gsub("^%s*(.-)%s*$", "%1"))
end

function M.is_true(value)
  return value == true or value == "true"
end

function M.round(value)
  return math.floor(value + 0.5)
end

function M.clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local DATE_TOKENS = {
  { "YYYY", "\1" }, { "yyyy", "\1" },
  { "YY", "\2" }, { "yy", "\2" },
  { "dddd", "\3" }, { "ddd", "\4" },
  { "MM", "\5" },
  { "DD", "\6" }, { "dd", "\6" },
  { "HH", "\7" }, { "hh", "\8" },
  { "mm", "\9" }, { "ss", "\11" },
  { "A", "\12" },
}

local DATE_STRFTIME = {
  ["\1"] = "%Y", ["\2"] = "%y", ["\3"] = "%A", ["\4"] = "%a",
  ["\5"] = "%m", ["\6"] = "%d", ["\7"] = "%H", ["\8"] = "%I",
  ["\9"] = "%M", ["\11"] = "%S", ["\12"] = "%p",
}

function M.date_format(pattern)
  local out = pattern
  for _, pair in ipairs(DATE_TOKENS) do
    out = out:gsub(pair[1], pair[2])
  end
  return (out:gsub("[\1-\12]", DATE_STRFTIME))
end

-- wttr.in reads the path as the location and gives +, @, ~ and , their own
-- meaning, so those stay; everything else is encoded. That covers place names
-- carrying an apostrophe - N'Djamena, Val-d'Or - which would otherwise close
-- the quoting of the command the value is interpolated into.
function M.url_encode(text)
  return (tostring(text):gsub("[^%w%-%._~%+@,]", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

function M.file_exists(path)
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

return M
