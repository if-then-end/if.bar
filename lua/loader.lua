local common = require("widgets.common")

local spacer_index = 0

local function add_spacer(position, width)
  spacer_index = spacer_index + 1
  local name = "spacer_" .. spacer_index
  sbar.add("item", name, {
    position = position,
    width = width,
  })
  return name
end

local function load_group(cfg, names, position)
  local pending = {}

  for _, entry in ipairs(names) do
    local ok, widget = pcall(require, "widgets." .. entry)
    if ok and type(widget) == "function" then
      pending[#pending + 1] = { name = entry, draw = widget }
    else
      print("[sketchybar] widget '" .. entry .. "' failed to load: " .. tostring(widget))
    end
  end

  local groups = {}
  local spacer

  for _, entry in ipairs(pending) do
    if #groups > 0 and cfg.auto_insert_spacer then
      local previous = groups[#groups].widget
      local boundary = cfg.standalone[previous] or cfg.standalone[entry.name]
      spacer = add_spacer(position, boundary and cfg.item.group_gap or cfg.item.spacer_width)
    end

    common.reset()
    local ok, drawn = pcall(entry.draw, cfg, position, nil)
    local created = common.collect()

    if not ok then
      print("[sketchybar] widget '" .. entry.name .. "' failed to draw: " .. tostring(drawn))
      drawn = false
    end

    if drawn ~= false and #created > 0 then
      groups[#groups + 1] = { widget = entry.name, items = created }
      spacer = nil
    elseif spacer then
      sbar.remove(spacer)
      spacer = nil
    end
  end

  return groups
end

return function(cfg)
  cfg.groups = {}
  cfg.loaded = {}

  for _, position in ipairs({ "left", "center", "right" }) do
    local groups = load_group(cfg, cfg.widgets[position], position)
    cfg.groups[position] = groups

    local widgets = {}
    for _, group in ipairs(groups) do
      widgets[#widgets + 1] = group.widget
    end
    cfg.loaded[position] = widgets
  end
end
