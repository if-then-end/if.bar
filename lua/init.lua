local config = require("config").load()

sbar.default({
  icon = {
    font = config.font.icon_bold .. ":" .. config.font.icon_size,
    color = config.color.default_icon,
  },
  label = {
    font = config.font.label_bold .. ":" .. config.font.label_size,
    color = config.color.default_label,
  },
})

sbar.bar({
  position = config.bar.position,
  height = config.bar.height,
  color = config.bar.color,
})

require("loader")(config)
require("styles")(config)
require("events")(config)
