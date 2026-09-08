local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

return function(cfg, position)
  local label = common.add_label(cfg, "weather.label", position, {
    update_freq = 600,
    updates = true,
    label = { string = icons.widget("loading") },
  })

  local icon = common.add_icon(cfg, "weather.icon", position, "", {
    icon = {
      font = common.icon_font(cfg, 12.5),
      padding_left = cfg.item.icon_padding_left - 4.0,
    },
  })

  local url = "wttr.in/" .. util.url_encode(cfg.widget.weather_location) .. "?format=j1"
  local query = "curl -s '" .. url .. "' | jq -r '"
    .. "[.current_condition[0].temp_C, .current_condition[0].weatherCode,"
    .. " .weather[0].astronomy[0].sunrise, .weather[0].astronomy[0].sunset] | @tsv'"

  local function to_minutes(clock)
    local hour, minute, meridiem = clock:match("(%d+):(%d+)%s*(%a*)")
    if not hour then
      return nil
    end
    hour, minute = tonumber(hour), tonumber(minute)
    if meridiem == "PM" and hour ~= 12 then
      hour = hour + 12
    elseif meridiem == "AM" and hour == 12 then
      hour = 0
    end
    return hour * 60 + minute
  end

  local function update()
    sbar.exec(query, function(result)
      local temp, code, sunrise, sunset = result:match("([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t\n]*)")
      if not temp or temp == "" then
        icon:set({ icon = icons.weather(113, true) })
        label:set({ label = "N/A" })
        return
      end

      local is_day = true
      local rise, set = to_minutes(sunrise or ""), to_minutes(sunset or "")
      if rise and set then
        local now = os.date("*t")
        local minutes = now.hour * 60 + now.min
        is_day = minutes >= rise and minutes < set
      end

      icon:set({ icon = icons.weather(code, is_day) })
      label:set({ label = temp .. "°C" })
    end)
  end

  label:subscribe({ "routine", "forced", "system_woke" }, update)
  update()
end
