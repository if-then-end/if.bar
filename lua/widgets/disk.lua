local common = require("widgets.common")
local icons = require("icons")

return function(cfg, position)
  local label = common.add_label(cfg, "disk.percent", position, { update_freq = cfg.freq.default })
  common.add_icon(cfg, "disk.icon", position, icons.widget("disk"))

  local function update()
    sbar.exec("df -k / | awk 'NR==2{printf \"%d%%\", int(($2 - $4) / $2 * 100)}'", function(result)
      label:set({ label = result })
    end)
  end

  label:subscribe({ "routine", "forced", "system_woke" }, update)
end
