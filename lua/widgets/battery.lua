local common = require("widgets.common")
local icons = require("icons")

return function(config, position)
  local percent = common.add_label(config, "battery.percent", position, { update_freq = config.freq.fast })
  local icon = common.add_icon(config, "battery.icon", position, "", {
    icon = { font = common.icon_font(config, 4) },
  })

  local function update()
    sbar.exec("pmset -g batt", function(info)
      local charge = tonumber(info:match("(%d+)%%"))
      if not charge then
        return
      end

      local name
      if info:find("AC Power") or charge >= 75 then
        name = "battery_full"
      elseif charge >= 50 then
        name = "battery_medium"
      elseif charge >= 25 then
        name = "battery_low"
      else
        name = "battery_empty"
      end

      icon:set({ icon = icons.widget(name) })
      percent:set({ label = charge .. "%" })
    end)
  end

  percent:subscribe({ "routine", "forced", "power_source_change", "system_woke" }, update)
end
