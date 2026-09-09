local common = require("widgets.common")
local icons = require("icons")

return function(config, position)
  if not config.widget.front_app_visible then
    return false
  end

  common.add_icon(config, "front_app.icon", position, "", {
    icon = { font = config.font.app_icon .. ":Regular:" .. config.font.app_icon_size },
  })

  local name = common.add_label(config, "front_app.name", position)

  name:subscribe({ "front_app_switched", "yabai_window_focus" }, function(env)
    if not env.INFO or env.INFO == "" then
      return
    end
    sbar.set("front_app.icon", { icon = icons.app(env.INFO) })
    name:set({ label = env.INFO })
  end)
end
