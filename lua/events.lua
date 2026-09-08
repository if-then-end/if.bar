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

return function(cfg)
  sbar.add("event", "yabai_window_focus")
  sbar.add("event", "caffeinate_update")

  local system = sbar.add("item", "system_events", {
    position = "left",
    drawing = false,
  })

  sbar.add("event", "system_woke")
  system:subscribe("system_woke", function()
    sbar.exec("sketchybar --reload")
  end)

  local layout
  local probing = false
  local reloading = false

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
      reloading = true
      sbar.exec("sleep " .. RELOAD_DELAY .. "; sketchybar --reload", function()
        reloading = false
      end)
    end)
  end)
end
