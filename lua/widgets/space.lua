local common = require("widgets.common")
local icons = require("icons")

local function query_spaces()
  local handle = io.popen("yabai -m query --spaces 2>/dev/null | jq -r '.[].index' 2>/dev/null")
  if not handle then
    return { 1 }, false
  end

  local space_indexes = {}
  for line in handle:lines() do
    local index = tonumber(line)
    if index then
      space_indexes[#space_indexes + 1] = index
    end
  end
  handle:close()

  if #space_indexes == 0 then
    return { 1 }, false
  end
  return space_indexes, true
end

return function(config, position)
  local space_indexes, has_yabai = query_spaces()
  local app_font = config.font.app_icon .. ":Regular:"

  local function style(item, selected, has_apps)
    local color = selected and config.color.space_border or config.colors.COLOR_LIGHT_GRAY
    item:set({
      icon = {
        padding_left = has_apps and 8 or 4,
        padding_right = has_apps and 8 or 4,
        color = color,
        font = app_font .. config.font.app_icon_size,
      },
      label = { drawing = not has_apps, color = color },
      background = { drawing = false },
    })
  end

  local state = {}

  local function refresh(space_index)
    local entry = state[space_index]
    if not entry then
      return
    end

    if not has_yabai then
      style(entry.item, true, false)
      return
    end

    sbar.exec(
      "yabai -m query --windows --space " .. space_index .. " 2>/dev/null"
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

  for slot, space_index in ipairs(space_indexes) do
    common.track("space." .. space_index)
    local item = sbar.add("space", "space." .. space_index, {
      position = position,
      associated_space = space_index,
      icon = {
        string = "",
        font = app_font .. config.font.app_icon_size,
        color = config.colors.COLOR_WHITE,
        padding_left = config.item.icon_padding_left,
        padding_right = config.item.icon_padding_right,
      },
      label = {
        string = tostring(space_index),
        color = config.colors.COLOR_WHITE,
        padding_right = config.item.label_padding_right,
      },
      padding_left = slot == 1 and 2 or 4,
      padding_right = slot == #space_indexes and 2 or 4,
      background = {
        corner_radius = config.item.bg_corner_radius,
        height = config.item.bg_height,
        border_width = config.item.bg_border_width,
        border_color = config.color.space_border,
        drawing = false,
      },
    })

    state[space_index] = { item = item, selected = false, has_apps = false }

    item:subscribe("space_change", function(env)
      local entry = state[space_index]
      entry.selected = env.SELECTED == "true"
      style(entry.item, entry.selected, entry.has_apps)
    end)

    item:subscribe({ "front_app_switched", "yabai_window_focus", "system_woke" }, function()
      refresh(space_index)
    end)

    item:subscribe("mouse.clicked", function()
      if has_yabai then
        sbar.exec("yabai -m space --focus " .. space_index)
      end
    end)

    refresh(space_index)
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
