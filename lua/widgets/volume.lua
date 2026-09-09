local common = require("widgets.common")
local icons = require("icons")

local function icon_for(volume)
  if volume > 66 then
    return "volume_high"
  elseif volume > 33 then
    return "volume_medium"
  elseif volume > 0 then
    return "volume_low"
  end
  return "volume_mute"
end

return function(config, position)
  local label = common.add_label(config, "volume.label", position)
  local icon = common.add_icon(config, "volume.icon", position, icons.widget("volume_mute"), {
    icon = { font = common.icon_font(config, 4) },
  })

  local function render(volume, muted)
    if muted then
      icon:set({ icon = icons.widget("volume_mute") })
      label:set({ label = { string = "", padding_right = 0 } })
      return
    end
    icon:set({ icon = icons.widget(icon_for(volume)) })
    label:set({
      label = { string = volume .. "%", padding_right = config.item.label_padding_right },
    })
  end

  local function refresh(volume)
    sbar.exec("osascript -e 'output muted of (get volume settings)'", function(result)
      render(volume, result:match("true") ~= nil)
    end)
  end

  label:subscribe("volume_change", function(env)
    refresh(tonumber(env.INFO) or 0)
  end)

  label:subscribe({ "forced", "system_woke" }, function()
    sbar.exec("osascript -e 'output volume of (get volume settings)'", function(result)
      refresh(tonumber(result) or 0)
    end)
  end)

  local function toggle_mute()
    sbar.exec("osascript -e 'set volume output muted not (output muted of (get volume settings))'", function()
      sbar.exec("osascript -e 'output volume of (get volume settings)'", function(result)
        refresh(tonumber(result) or 0)
      end)
    end)
  end

  label:subscribe("mouse.clicked", toggle_mute)
  icon:subscribe("mouse.clicked", toggle_mute)

  sbar.exec("osascript -e 'output volume of (get volume settings)'", function(result)
    refresh(tonumber(result) or 0)
  end)
end
