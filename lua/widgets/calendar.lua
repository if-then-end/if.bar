local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

return function(config, position)
  local format = util.date_format(config.widget.calendar_format)

  local label = common.add_label(config, "calendar.label", position, { update_freq = 10 })
  common.add_icon(config, "calendar.icon", position, icons.widget("calendar"))

  local function update()
    label:set({ label = os.date(format) })
  end

  label:subscribe({ "routine", "forced", "system_woke" }, update)
  update()
end
