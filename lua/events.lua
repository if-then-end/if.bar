local SETTLE_DELAY = "0.5"
local RELOAD_DELAY = "1"

local function fingerprint(displays)
  if type(displays) ~= "table" or #displays == 0 then
    return nil
  end

  local parts = {}
  for _, display in ipairs(displays) do
    local frame = display.frame or {}
    parts[#parts + 1] = table.concat({
      tostring(display.UUID),
      tostring(frame.x),
      tostring(frame.y),
      tostring(frame.w),
      tostring(frame.h),
    }, ",")
  end

  return table.concat(parts, ";")
end

return function(config)
  sbar.add("event", "yabai_window_focus")
  sbar.add("event", "caffeinate_update")

  local system = sbar.add("item", "system_events", {
    position = "left",
    drawing = false,
  })

  local layout
  local probing = false
  local reloading = false

  -- A wake arrives as two system_woke events half a second apart, each of them
  -- carrying a display change, so reloading on the spot rebuilt the bar three
  -- times over. One delayed reload absorbs the burst, and waiting also lets the
  -- displays and the spaces settle before the widgets are rebuilt from them.
  local function reload_once()
    if reloading then
      return
    end
    reloading = true
    sbar.exec("sleep " .. RELOAD_DELAY .. "; sketchybar --reload", function()
      reloading = false
    end)
  end

  sbar.add("event", "system_woke")
  system:subscribe("system_woke", reload_once)

  local function probe(handler)
    probing = true
    sbar.exec("sleep " .. SETTLE_DELAY .. "; sketchybar --query displays", function(result)
      probing = false
      local current = fingerprint(result)
      if current then
        handler(current)
      end
    end)
  end

  probe(function(current)
    layout = layout or current
  end)

  system:subscribe("display_change", function()
    if probing or reloading then
      return
    end

    probe(function(current)
      if layout == nil or current == layout then
        layout = current
        return
      end

      layout = current
      reload_once()
    end)
  end)
end
