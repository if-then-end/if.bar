local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

return function(cfg, position)
  local format = util.date_format(cfg.widget.calendar_format)

  local label = common.add_label(cfg, "calendar.label", position, { update_freq = 10 })
  common.add_icon(cfg, "calendar.icon", position, icons.widget("calendar"))

  local function update()
    label:set({ label = os.date(format) })
  end

  label:subscribe({ "routine", "forced", "system_woke" }, update)
  update()
end
