local util = require("util")

local M = {}

local DEFAULT_THEME = "onedark"

local function theme_path(name)
  return require("paths") .. "/lua/themes/" .. name .. ".lua"
end

function M.load(name)
  local path = theme_path(name or DEFAULT_THEME)
  if not util.file_exists(path) then
    path = theme_path(DEFAULT_THEME)
  end

  local theme = dofile(path)

  local colors = {
    COLOR_TRANSPARENT = theme.transparent,
    COLOR_LIGHT_GRAY = theme.light_gray,
    COLOR_DARK_GRAY = theme.dark_gray,
    COLOR_BG1 = theme.bg1,
    COLOR_BG2 = theme.bg2,
  }

  for key, base in pairs(theme.base) do
    local upper = key:upper()
    colors["COLOR_" .. upper] = util.alpha(base, 100)
    colors["COLOR_" .. upper .. "_75"] = util.alpha(base, 75)
    colors["COLOR_" .. upper .. "_50"] = util.alpha(base, 50)
    colors["COLOR_" .. upper .. "_25"] = util.alpha(base, 25)
  end

  return {
    type = theme.type,
    colors = colors,
  }
end

function M.badge_label_color(theme)
  if theme.type == "light" then
    return theme.colors.COLOR_WHITE
  end
  return theme.colors.COLOR_BLACK
end

return M
