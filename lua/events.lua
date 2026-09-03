return function(cfg)
  sbar.add("event", "yabai_window_focus")
  sbar.add("event", "caffeinate_update")

  local woke = sbar.add("item", "system_woke", {
    position = "left",
    drawing = false,
  })

  sbar.add("event", "system_woke")
  woke:subscribe("system_woke", function()
    sbar.exec("sketchybar --reload")
  end)
end
