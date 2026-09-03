local M = {}

local base = require("paths") .. "/lua/icons/"

local apps = dofile(base .. "apps.lua")
local widget = dofile(base .. "widget.lua")
local weather = dofile(base .. "weather.lua")

local WEATHER_CODES = {
  [113] = "clear",
  [116] = "partly_cloudy",
  [122] = "partly_cloudy",
  [119] = "cloudy",
  [143] = "fog",
  [248] = "fog",
  [260] = "fog",
  [176] = "rain",
  [185] = "rain",
  [263] = "rain",
  [266] = "rain",
  [281] = "rain",
  [284] = "rain",
  [293] = "rain",
  [296] = "rain",
  [299] = "rain",
  [302] = "rain",
  [305] = "rain",
  [308] = "rain",
  [311] = "rain",
  [314] = "rain",
  [353] = "rain",
  [356] = "rain",
  [359] = "rain",
  [179] = "snow",
  [227] = "snow",
  [230] = "snow",
  [323] = "snow",
  [326] = "snow",
  [329] = "snow",
  [332] = "snow",
  [335] = "snow",
  [338] = "snow",
  [368] = "snow",
  [371] = "snow",
  [350] = "hail",
  [374] = "hail",
  [377] = "hail",
  [392] = "hail",
  [395] = "hail",
  [182] = "sleet",
  [317] = "sleet",
  [320] = "sleet",
  [362] = "sleet",
  [365] = "sleet",
  [200] = "thunderstorm",
  [386] = "thunderstorm",
  [389] = "thunderstorm",
}

function M.app(name)
  if not name then
    return apps.default
  end
  local icon = apps.exact[name]
  if icon then
    return icon
  end
  for _, entry in ipairs(apps.prefix) do
    if name:sub(1, #entry[1]) == entry[1] then
      return entry[2]
    end
  end
  return apps.default
end

function M.widget(name)
  return widget.exact[name] or widget.default
end

function M.weather(code, is_day)
  local kind = WEATHER_CODES[tonumber(code)]
  local name
  if kind then
    name = "weather_" .. kind .. (is_day and "_day" or "_night")
  else
    name = "weather_default"
  end
  return weather.exact[name] or weather.default
end

return M
