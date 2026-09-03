local common = require("widgets.common")
local icons = require("icons")
local theme = require("theme")

return function(cfg, position)
  common.track("kakaotalk.badge")
  local badge = sbar.add("item", "kakaotalk.badge", {
    position = position,
    label = {
      drawing = false,
      font = cfg.font.label_bold .. ":7.0",
      color = "0xFFFFFFFF",
      padding_left = 4,
      padding_right = 4,
    },
    background = {
      color = cfg.colors.COLOR_RED,
      corner_radius = 7,
      height = 14,
      drawing = false,
    },
    y_offset = -10,
  })

  local icon = common.add_icon(cfg, "kakaotalk.icon", position, icons.app("KakaoTalk"), {
    update_freq = 10,
    icon = { font = cfg.font.app_icon .. ":Regular:" .. cfg.font.app_icon_size },
  })

  badge:set({ label = { color = theme.badge_label_color(cfg.theme) } })

  local function update()
    sbar.exec("pgrep -x KakaoTalk >/dev/null && echo running || echo stopped", function(state)
      if state:match("stopped") then
        icon:set({ drawing = false })
        badge:set({ drawing = false })
        return
      end

      icon:set({ drawing = true })

      sbar.exec(
        "lsappinfo -all list | grep -A 1 '\"KakaoTalk\"' | grep StatusLabel"
          .. " | sed 's/.*\"label\"=//; s/\"//g; s/ }.*//'",
        function(raw)
          local value = raw:gsub("%s+", "")
          local unread = value ~= "" and value ~= "0" and value ~= "kCFNULL"

          badge:set({
            drawing = unread,
            label = { string = unread and "NEW" or "", drawing = unread },
            background = { drawing = unread },
            y_offset = unread and 10 or 0,
            padding_left = unread and -22 or 0,
          })
        end
      )
    end)
  end

  icon:subscribe({ "routine", "forced", "system_woke" }, update)

  icon:subscribe("mouse.clicked", function()
    sbar.exec("open -a KakaoTalk")
  end)

  update()
end
