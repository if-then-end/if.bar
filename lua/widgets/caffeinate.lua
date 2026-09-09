local common = require("widgets.common")
local icons = require("icons")

local STATE_DIR = '"$HOME/.local/state/if.bar"'
local PID_FILE = '"$HOME/.local/state/if.bar/caffeinate.pid"'

return function(config, position)
  local icon = common.add_icon(config, "caffeinate.icon", position, icons.widget("coffee_on"), {
    icon = {
      font = common.icon_font(config, 3),
      padding_right = config.item.label_padding_right - 2,
    },
  })

  local function render(active)
    icon:set({
      icon = {
        string = icons.widget(active and "coffee_off" or "coffee_on"),
        color = active and config.color.caffeinate_on or config.color.caffeinate,
      },
    })
  end

  local function refresh()
    sbar.exec(
      "if [ -f " .. PID_FILE .. " ] && kill -0 \"$(cat " .. PID_FILE .. ")\" 2>/dev/null"
        .. " && ps -p \"$(cat " .. PID_FILE .. ")\" -o comm= | grep -q caffeinate;"
        .. " then echo on; else rm -f " .. PID_FILE .. "; echo off; fi",
      function(result)
        render(result:match("on") ~= nil)
      end
    )
  end

  icon:set({ update_freq = config.freq.slow, updates = true })
  icon:subscribe({ "routine", "forced", "caffeinate_update", "system_woke" }, refresh)

  icon:subscribe("mouse.clicked", function()
    sbar.exec(
      "mkdir -p " .. STATE_DIR .. " && chmod 700 " .. STATE_DIR .. ";"
        .. " if [ -f " .. PID_FILE .. " ] && kill -0 \"$(cat " .. PID_FILE .. ")\" 2>/dev/null"
        .. " && ps -p \"$(cat " .. PID_FILE .. ")\" -o comm= | grep -q caffeinate;"
        .. " then kill \"$(cat " .. PID_FILE .. ")\"; rm -f " .. PID_FILE .. "; echo off;"
        .. " else rm -f " .. PID_FILE .. "; caffeinate -d >/dev/null 2>&1 & echo $! > " .. PID_FILE .. "; echo on; fi",
      function(result)
        render(result:match("on") ~= nil)
      end
    )
  end)

  refresh()
end
