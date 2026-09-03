local cfg = require("config").load()

sbar.default({
  icon = {
    font = cfg.font.icon_bold .. ":" .. cfg.font.icon_size,
    color = cfg.color.default_icon,
  },
  label = {
    font = cfg.font.label_bold .. ":" .. cfg.font.label_size,
    color = cfg.color.default_label,
  },
})

sbar.bar({
  position = cfg.bar.position,
  height = cfg.bar.height,
  color = cfg.bar.color,
})

require("loader")(cfg)
require("styles")(cfg)
require("events")(cfg)
