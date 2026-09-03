local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

return function(cfg, position)
  local format = util.date_format(cfg.widget.clock_format)

  local label = common.add_label(cfg, "clock.label", position, { update_freq = 1 })
  common.add_icon(cfg, "clock.icon", position, icons.widget("clock"))

  local function update()
    label:set({ label = os.date(format) })
  end

  label:subscribe({ "routine", "forced", "system_woke" }, update)
  update()
end
