local M = {}

M.created = {}

function M.reset()
  M.created = {}
end

function M.track(name)
  M.created[#M.created + 1] = name
  return name
end

function M.collect()
  local out = M.created
  M.created = {}
  return out
end

function M.icon_font(config, delta)
  return config.font.icon_bold .. ":" .. (config.font.icon_size + (delta or 0))
end

function M.label_font(config, size)
  return config.font.label_regular .. ":" .. size
end

function M.add_label(config, name, position, props)
  local base = {
    position = position,
    label = {
      color = config.colors.COLOR_BLACK,
      padding_right = config.item.label_padding_right,
    },
  }
  for key, value in pairs(props or {}) do
    if key == "label" then
      for field, setting in pairs(value) do
        base.label[field] = setting
      end
    else
      base[key] = value
    end
  end
  M.track(name)
  return sbar.add("item", name, base)
end

function M.add_icon(config, name, position, glyph, props)
  local base = {
    position = position,
    icon = {
      string = glyph,
      font = M.icon_font(config),
      color = config.colors.COLOR_BLACK,
      padding_left = config.item.icon_padding_left,
      padding_right = config.item.icon_padding_right,
    },
  }
  for key, value in pairs(props or {}) do
    if key == "icon" then
      for field, setting in pairs(value) do
        base.icon[field] = setting
      end
    else
      base[key] = value
    end
  end
  M.track(name)
  return sbar.add("item", name, base)
end

function M.set_group_visible(group, spacer, visible)
  sbar.set(group, { background = { drawing = visible } })
  if spacer then
    sbar.set(spacer.name, { width = visible and spacer.width or 0 })
  end
end

return M
