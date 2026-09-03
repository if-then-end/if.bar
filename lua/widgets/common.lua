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

function M.icon_font(cfg, delta)
  return cfg.font.icon_bold .. ":" .. (cfg.font.icon_size + (delta or 0))
end

function M.label_font(cfg, size)
  return cfg.font.label_regular .. ":" .. size
end

function M.add_label(cfg, name, position, props)
  local base = {
    position = position,
    label = {
      color = cfg.colors.COLOR_BLACK,
      padding_right = cfg.item.label_padding_right,
    },
  }
  for key, value in pairs(props or {}) do
    if key == "label" then
      for k, v in pairs(value) do
        base.label[k] = v
      end
    else
      base[key] = value
    end
  end
  M.track(name)
  return sbar.add("item", name, base)
end

function M.add_icon(cfg, name, position, glyph, props)
  local base = {
    position = position,
    icon = {
      string = glyph,
      font = M.icon_font(cfg),
      color = cfg.colors.COLOR_BLACK,
      padding_left = cfg.item.icon_padding_left,
      padding_right = cfg.item.icon_padding_right,
    },
  }
  for key, value in pairs(props or {}) do
    if key == "icon" then
      for k, v in pairs(value) do
        base.icon[k] = v
      end
    else
      base[key] = value
    end
  end
  M.track(name)
  return sbar.add("item", name, base)
end

return M
