local common = require("widgets.common")
local icons = require("icons")

return function(cfg, position)
  local target
  local busy = false

  if cfg.widget.cpu_show_graph then
    common.track("cpu.graph")
    target = sbar.add("graph", "cpu.graph", 42, {
      position = position,
      width = 42,
      update_freq = cfg.freq.fast,
      graph = {
        color = cfg.colors.COLOR_BLUE_75,
        fill_color = cfg.colors.COLOR_BLACK_25,
      },
      background = {
        height = 22,
        color = "0x00000000",
        border_color = "0x00000000",
        drawing = true,
      },
      label = {
        color = cfg.colors.COLOR_BLACK,
        font = common.label_font(cfg, 8.5),
        padding_right = 0,
        padding_left = -20,
        y_offset = 6,
      },
    })
  elseif cfg.widget.cpu_show_percent then
    target = common.add_label(cfg, "cpu.percent", position, {
      update_freq = cfg.freq.fast,
      label = { padding_left = 0 },
    })
  end

  common.add_icon(cfg, "cpu.icon", position, icons.widget("cpu"), {
    icon = { font = common.icon_font(cfg, 4) },
  })

  if not target then
    return
  end

  local function update()
    if busy then
      return
    end
    busy = true
    sbar.exec("top -l 2 -n 0 | grep -E '^CPU' | tail -1", function(result)
      busy = false
      local user, sys = result:match("(%d+%.?%d*)%%%s+user,%s+(%d+%.?%d*)%%%s+sys")
      if not user then
        return
      end
      local load = math.floor(tonumber(user) + tonumber(sys))
      if cfg.widget.cpu_show_graph then
        target:push({ load / 100 })
      end
      target:set({ label = load .. "%" })
    end)
  end

  target:subscribe({ "routine", "forced", "system_woke" }, update)
end
