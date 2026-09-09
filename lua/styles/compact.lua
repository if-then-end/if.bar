local theme = require("theme")

local WIDGET_PARTS = {
  clock = { "icon", "label" },
  calendar = { "icon", "label" },
  weather = { "icon", "label" },
  caffeinate = { "icon" },
  volume = { "icon", "label" },
  battery = { "icon", "label" },
  disk = { "icon", "label" },
  ram = { "icon", "label" },
  cpu = { "icon", "label" },
  netstat = { "icon", "label" },
  front_app = { "icon", "label" },
  kakaotalk = { "icon" },
  last_command = { "icon", "label" },
  running_command = { "icon", "label" },
}

return function(config)
  local drawn = {}
  for _, position in ipairs({ "left", "center", "right" }) do
    for _, name in ipairs(config.loaded[position] or {}) do
      drawn[name] = true
    end
  end

  for widget in pairs(drawn) do
    local parts = WIDGET_PARTS[widget]
    local color = config.color[widget]
    if parts and color then
      local props = {}
      for _, part in ipairs(parts) do
        props[part] = { color = color }
      end
      sbar.set("/" .. widget .. "\\..*/", props)
    end
  end

  if drawn.kakaotalk then
    sbar.set("kakaotalk.badge", { label = { color = theme.badge_label_color(config.theme) } })
  end

  local container = {
    background = {
      color = config.item.compact_bg_color,
      corner_radius = config.item.bg_corner_radius,
      height = config.item.bg_height,
      border_width = config.item.bg_border_width,
      drawing = true,
    },
  }

  for _, position in ipairs({ "left", "center", "right" }) do
    local shared = {}
    local run = 0

    local function flush()
      if #shared == 0 then
        return
      end
      run = run + 1
      local name = "container_" .. position
      if run > 1 then
        name = name .. "_" .. run
      end
      sbar.add("bracket", name, shared, container)
      shared = {}
    end

    for _, group in ipairs(config.groups[position] or {}) do
      if config.standalone[group.widget] then
        flush()
        sbar.add("bracket", "group_" .. group.widget, group.items, container)
      else
        for _, item in ipairs(group.items) do
          shared[#shared + 1] = item
        end
      end
    end

    flush()
  end
end
