local util = require("util")
local theme_loader = require("theme")

local M = {}

local function unquote(value)
  value = util.trim(value)
  local quoted = value:match('^"([^"]*)"') or value:match("^'([^']*)'")
  if quoted then
    return quoted
  end
  return util.trim((value:gsub("%s+#.*$", "")))
end

local function parse_user_config(path)
  local raw = {}
  if not util.file_exists(path) then
    return raw
  end

  for line in io.lines(path) do
    local key, value = line:match("^%s*export%s+([%w_]+)%s*=%s*(.*)$")
    if not key then
      key, value = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
    end
    if key then
      raw[key] = unquote(value)
    end
  end

  return raw
end

local function resolve(value, colors)
  if type(value) ~= "string" then
    return value
  end
  local resolved = value:gsub("%${([%w_]+)}", function(name)
    return colors[name] or ""
  end)
  resolved = resolved:gsub("%$([%w_]+)", function(name)
    return colors[name] or ""
  end)
  return resolved
end

local function pick(raw, key, fallback)
  local value = raw[key]
  if value == nil or value == "" then
    return fallback
  end
  return value
end

local function number(raw, key, fallback)
  local value = raw[key]
  if value == nil or value == "" then
    return fallback
  end
  return tonumber(value) or fallback
end

local function boolean(raw, key, fallback)
  local value = raw[key]
  if value == nil or value == "" then
    return fallback
  end
  return value == "true"
end

local function split(value)
  local out = {}
  for word in tostring(value):gmatch("%S+") do
    out[#out + 1] = word
  end
  return out
end

local RENAMED = {
  IF_BAR_BAR_HEIGHT = "IF_BAR_HEIGHT",
  IF_BAR_BAR_POSITION = "IF_BAR_POSITION",
  IF_BAR_BAR_BACKGROUND = "IF_BAR_BACKGROUND",
}

local function migrate(raw)
  local add = {}
  for key, value in pairs(raw) do
    local legacy = key:match("^SBAR_(.+)$")
    local current = legacy and ("IF_BAR_" .. legacy) or key
    local target = RENAMED[current] or current
    if target ~= key and raw[target] == nil then
      add[target] = value
    end
  end
  for key, value in pairs(add) do
    raw[key] = value
  end
end

function M.load()
  local config_dir = require("paths")
  local raw = parse_user_config(config_dir .. "/ifbarrc")
  if next(raw) == nil then
    raw = parse_user_config(config_dir .. "/user.sketchybarrc")
  end
  migrate(raw)

  local theme = theme_loader.load(raw.IF_BAR_THEME)
  local c = theme.colors

  for key, value in pairs(raw) do
    raw[key] = resolve(value, c)
  end

  local label_font = pick(raw, "IF_BAR_LABEL_FONT_FAMILY", "SpaceMono Nerd Font Mono")
  local icon_font = pick(raw, "IF_BAR_ICON_FONT_FAMILY", label_font)
  local bar_background = pick(raw, "IF_BAR_BACKGROUND", "transparent")

  local cfg = {
    theme = theme,
    colors = c,

    bar = {
      height = number(raw, "IF_BAR_HEIGHT", 56),
      position = pick(raw, "IF_BAR_POSITION", "top"),
      background = bar_background,
      color = bar_background == "bg1" and c.COLOR_BG1 or c.COLOR_TRANSPARENT,
    },

    font = {
      label_family = label_font,
      icon_family = icon_font,
      icon_regular = icon_font .. ":Regular",
      icon_bold = icon_font .. ":Bold",
      label_regular = label_font .. ":Regular",
      label_bold = label_font .. ":Bold",
      icon_size = number(raw, "IF_BAR_ICON_FONT_SIZE", 18.0),
      label_size = number(raw, "IF_BAR_LABEL_FONT_SIZE", 12.0),
      app_icon = pick(raw, "IF_BAR_APP_ICON_FONT", "sketchybar-app-font"),
      app_icon_size = number(raw, "IF_BAR_APP_ICON_FONT_SIZE", 13.5),
      claude_icon_size = number(
        raw,
        "IF_BAR_CLAUDE_ICON_SIZE",
        number(raw, "IF_BAR_APP_ICON_FONT_SIZE", 13.5)
      ),
    },

    item = {
      bg_height = 24,
      bg_corner_radius = 4,
      bg_border_width = 1,
      icon_padding_left = 8,
      icon_padding_right = 4,
      label_padding_left = 0,
      label_padding_right = 8,
      spacer_width = number(raw, "IF_BAR_SPACER_WIDTH", 8),
      group_gap = number(raw, "IF_BAR_GROUP_GAP", 20),
      compact_bg_color = pick(raw, "IF_BAR_COMPACT_BG_COLOR", c.COLOR_BG2),
    },

    popup = {
      icon_padding_left = 12,
      icon_padding_right = 8,
      padding_left = 8,
      padding_right = 12,
    },

    freq = {
      default = number(raw, "IF_BAR_ITEM_UPDATE_FREQ_DEFAULT", 10),
      fast = number(raw, "IF_BAR_ITEM_UPDATE_FREQ_FAST", 2),
      slow = number(raw, "IF_BAR_ITEM_UPDATE_FREQ_SLOW", 30),
    },

    color = {
      default_icon = pick(raw, "IF_BAR_DEFAULT_ICON_COLOR", c.COLOR_WHITE),
      default_label = pick(raw, "IF_BAR_DEFAULT_LABEL_COLOR", c.COLOR_WHITE),
      clock = pick(raw, "IF_BAR_COLOR_CLOCK", c.COLOR_YELLOW),
      calendar = pick(raw, "IF_BAR_COLOR_CALENDAR", c.COLOR_TANGERINE),
      weather = pick(raw, "IF_BAR_COLOR_WEATHER", c.COLOR_CYAN),
      caffeinate = pick(raw, "IF_BAR_COLOR_CAFFEINATE", c.COLOR_GREEN),
      caffeinate_on = pick(raw, "IF_BAR_COLOR_CAFFEINATE_ON", c.COLOR_RED),
      volume = pick(raw, "IF_BAR_COLOR_VOLUME", c.COLOR_BLUE),
      battery = pick(raw, "IF_BAR_COLOR_BATTERY", c.COLOR_ORANGE),
      disk = pick(raw, "IF_BAR_COLOR_DISK", c.COLOR_RED),
      ram = pick(raw, "IF_BAR_COLOR_RAM", c.COLOR_MAGENTA),
      cpu = pick(raw, "IF_BAR_COLOR_CPU", c.COLOR_BLUE),
      netstat = pick(raw, "IF_BAR_COLOR_NETSTAT", c.COLOR_TANGERINE),
      kakaotalk = pick(raw, "IF_BAR_COLOR_KAKAOTALK", c.COLOR_YELLOW),
      front_app = pick(raw, "IF_BAR_COLOR_FRONT_APP", c.COLOR_GREEN),
      space = pick(raw, "IF_BAR_COLOR_SPACE", "0xFF24242f"),
      space_border = pick(raw, "IF_BAR_COLOR_SPACE_BORDER", c.COLOR_GREEN),
      last_command = pick(raw, "IF_BAR_COLOR_LAST_COMMAND", c.COLOR_CYAN),
      last_command_error = pick(raw, "IF_BAR_COLOR_LAST_COMMAND_ERROR", c.COLOR_RED),
      last_command_claude = pick(raw, "IF_BAR_COLOR_LAST_COMMAND_CLAUDE", c.COLOR_MAGENTA),
      running_command = pick(raw, "IF_BAR_COLOR_RUNNING_COMMAND", c.COLOR_YELLOW),
      running_command_claude = pick(raw, "IF_BAR_COLOR_RUNNING_COMMAND_CLAUDE", c.COLOR_MAGENTA),
    },

    widget = {
      clock_format = pick(raw, "IF_BAR_CLOCK_FORMAT", "MM/DD HH:mm"),
      calendar_format = pick(raw, "IF_BAR_CALENDAR_FORMAT", "YYYY-MM-DD"),
      weather_location = pick(raw, "IF_BAR_WEATHER_LOCATION", "Seoul"),
      netstat_show_graph = boolean(raw, "IF_BAR_NETSTAT_SHOW_GRAPH", true),
      netstat_show_speed = boolean(raw, "IF_BAR_NETSTAT_SHOW_SPEED", false),
      cpu_show_graph = boolean(raw, "IF_BAR_CPU_SHOW_GRAPH", true),
      cpu_show_percent = boolean(raw, "IF_BAR_CPU_SHOW_PERCENT", true),
      ram_show_graph = boolean(raw, "IF_BAR_RAM_SHOW_GRAPH", true),
      ram_show_percent = boolean(raw, "IF_BAR_RAM_SHOW_PERCENT", true),
      front_app_visible = boolean(raw, "IF_BAR_FRONT_APP_VISIBLE", true),
      last_command_max_length = number(raw, "IF_BAR_LAST_COMMAND_MAX_LENGTH", 60),
      claude_max_sessions = number(raw, "IF_BAR_CLAUDE_MAX_SESSIONS", 8),
    },
  }

  local left = raw.IF_BAR_WIDGETS_LEFT_ENABLED
  local center = raw.IF_BAR_WIDGETS_CENTER_ENABLED
  local right = raw.IF_BAR_WIDGETS_RIGHT_ENABLED

  cfg.widgets = {
    left = left and split(left) or { "space" },
    center = center and split(center) or { "front_app" },
    right = right and split(right)
      or { "clock", "weather", "caffeinate", "volume", "battery", "disk", "ram", "cpu", "kakaotalk" },
  }

  cfg.standalone = { space = true, claude = true, running_command = true }

  cfg.auto_insert_spacer = true

  return cfg
end

return M
