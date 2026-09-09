local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

local MAX_SPEED = 512000

local function format_speed(bytes)
  local value, unit
  if bytes > 1073741824 then
    value, unit = bytes // 1073741824, "G"
  elseif bytes > 1048576 then
    value, unit = bytes // 1048576, "M"
  elseif bytes > 1024 then
    value, unit = bytes // 1024, "K"
  else
    value, unit = bytes, "B"
  end
  return math.min(value, 999) .. unit
end

return function(config, position)
  local show_graph = config.widget.netstat_show_graph
  local show_speed = config.widget.netstat_show_speed

  local function build(direction, glyph)
    local target
    local name = "netstat." .. direction

    if show_graph then
      common.track(name .. ".graph")
      target = sbar.add("graph", name .. ".graph", 42, {
        position = position,
        width = 42,
        graph = {
          color = config.colors.COLOR_BLACK_25,
          fill_color = config.colors.COLOR_BLACK_25,
        },
        background = {
          height = 50,
          color = "0x00000000",
          border_color = "0x00000000",
          drawing = true,
        },
        label = {
          color = config.colors.COLOR_BLACK,
          font = common.label_font(config, 8.5),
          padding_right = 0,
          padding_left = -24,
          y_offset = 6,
        },
      })
    elseif show_speed then
      target = common.add_label(config, name .. ".label", position, {
        label = { padding_left = 0 },
      })
    end

    common.add_icon(config, name .. ".icon", position, icons.widget(glyph))
    return target
  end

  local down = build("down", "network_download")
  local up = build("up", "network_upload")

  if not down and not up then
    return
  end

  local driver = down or up
  driver:set({ update_freq = config.freq.fast })

  local busy = false

  local function update()
    if busy then
      return
    end
    busy = true

    sbar.exec("netstat -w1 | awk 'NR==4 {print; exit}'", function(result)
      busy = false
      local fields = {}
      for token in result:gmatch("%S+") do
        fields[#fields + 1] = token
      end

      local bytes_in = tonumber(fields[3]) or 0
      local bytes_out = tonumber(fields[6]) or 0

      if show_graph then
        down:push({ util.clamp(bytes_in / MAX_SPEED, 0, 1) })
        up:push({ util.clamp(bytes_out / MAX_SPEED, 0, 1) })
        down:set({ graph = { color = config.colors.COLOR_BLACK_50 }, label = format_speed(bytes_in) })
        up:set({ graph = { color = config.colors.COLOR_BLACK_50 }, label = format_speed(bytes_out) })
      else
        down:set({ label = format_speed(bytes_in) })
        up:set({ label = format_speed(bytes_out) })
      end
    end)
  end

  driver:subscribe({ "routine", "forced", "system_woke" }, update)
end
