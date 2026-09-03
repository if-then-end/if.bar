local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

return function(cfg, position)
  local target
  local busy = false

  if cfg.widget.ram_show_graph then
    common.track("ram.graph")
    target = sbar.add("graph", "ram.graph", 42, {
      position = position,
      width = 42,
      update_freq = cfg.freq.fast,
      graph = {
        color = cfg.colors.COLOR_MAGENTA_75,
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
  elseif cfg.widget.ram_show_percent then
    target = common.add_label(cfg, "ram.percent", position, {
      update_freq = cfg.freq.fast,
      label = { padding_left = 0 },
    })
  end

  common.add_icon(cfg, "ram.icon", position, icons.widget("memory"), {
    icon = { font = common.icon_font(cfg, 4) },
  })

  if not target then
    return
  end

  local command = table.concat({
    "total=$(sysctl -n hw.memsize)",
    "page=$(sysctl -n vm.pagesize)",
    "vm_stat | awk -v t=\"$total\" -v p=\"$page\" '",
    "/Pages active/ {a=$3} /Pages wired/ {w=$4}",
    "END { gsub(/\\./,\"\",a); gsub(/\\./,\"\",w); if (t>0) printf \"%d\", (a+w)*p*100/t; else print 0 }'",
  }, "; ")

  local function update()
    if busy then
      return
    end
    busy = true
    sbar.exec(command, function(result)
      busy = false
      local used = tonumber(result)
      if not used then
        return
      end
      used = util.clamp(math.floor(used), 0, 100)
      if cfg.widget.ram_show_graph then
        target:push({ used / 100 })
      end
      target:set({ label = used .. "%" })
    end)
  end

  target:subscribe({ "routine", "forced", "system_woke" }, update)
end
