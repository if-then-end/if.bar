local common = require("widgets.common")
local icons = require("icons")

local function query_spaces()
  local handle = io.popen("yabai -m query --spaces 2>/dev/null | jq -r '.[].index' 2>/dev/null")
  if not handle then
    return { 1 }, false
  end

  local ids = {}
  for line in handle:lines() do
    local id = tonumber(line)
    if id then
      ids[#ids + 1] = id
    end
  end
  handle:close()

  if #ids == 0 then
    return { 1 }, false
  end
  return ids, true
end

return function(cfg, position)
  local ids, has_yabai = query_spaces()
  local app_font = cfg.font.app_icon .. ":Regular:"

  local function style(item, selected, has_apps)
    local color = selected and cfg.color.space_border or cfg.colors.COLOR_LIGHT_GRAY
    item:set({
      icon = {
        padding_left = has_apps and 8 or 4,
        padding_right = has_apps and 8 or 4,
        color = color,
        font = app_font .. cfg.font.app_icon_size,
      },
      label = { drawing = not has_apps, color = color },
      background = { drawing = false },
    })
  end

  local state = {}

  local function refresh(sid)
    local entry = state[sid]
    if not entry then
      return
    end

    if not has_yabai then
      style(entry.item, true, false)
      return
    end

    sbar.exec(
      "yabai -m query --windows --space " .. sid .. " 2>/dev/null"
        .. " | jq -r '[.[] | select(.app | test(\"ClaudeMon\") | not)] | .[].app'"
        .. " | sort -u | grep -v '^$'",
      function(result)
        local glyphs = {}
        for app in result:gmatch("[^\n]+") do
          glyphs[#glyphs + 1] = icons.app(app)
        end
        local joined = table.concat(glyphs, " ")
        entry.item:set({ icon = { string = joined } })
        style(entry.item, entry.selected, joined ~= "")
        entry.has_apps = joined ~= ""
      end
    )
  end

  for index, sid in ipairs(ids) do
    common.track("space." .. sid)
    local item = sbar.add("space", "space." .. sid, {
      position = position,
      associated_space = sid,
      icon = {
        string = "",
        font = app_font .. cfg.font.app_icon_size,
        color = cfg.colors.COLOR_WHITE,
        padding_left = cfg.item.icon_padding_left,
        padding_right = cfg.item.icon_padding_right,
      },
      label = {
        string = tostring(sid),
        color = cfg.colors.COLOR_WHITE,
        padding_right = cfg.item.label_padding_right,
      },
      padding_left = index == 1 and 2 or 4,
      padding_right = index == #ids and 2 or 4,
      background = {
        corner_radius = cfg.item.bg_corner_radius,
        height = cfg.item.bg_height,
        border_width = cfg.item.bg_border_width,
        border_color = cfg.color.space_border,
        drawing = false,
      },
    })

    state[sid] = { item = item, selected = false, has_apps = false }

    item:subscribe("space_change", function(env)
      local entry = state[sid]
      entry.selected = env.SELECTED == "true"
      style(entry.item, entry.selected, entry.has_apps)
    end)

    item:subscribe({ "front_app_switched", "yabai_window_focus", "system_woke" }, function()
      refresh(sid)
    end)

    item:subscribe("mouse.clicked", function()
      if has_yabai then
        sbar.exec("yabai -m space --focus " .. sid)
      end
    end)

    refresh(sid)
  end

  if has_yabai then
    sbar.exec(
      "yabai -m query --spaces 2>/dev/null | jq -r '.[] | select(.\"has-focus\") | .index'",
      function(result)
        local focused = tonumber(result:match("%d+"))
        local entry = focused and state[focused]
        if entry then
          entry.selected = true
          style(entry.item, true, entry.has_apps)
        end
      end
    )
  end
end
