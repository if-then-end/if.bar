local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

local PULSE = { 50, 75, 100, 75 }
local PULSE_INTERVAL = 0.12

local SOURCES = { "user", "claude" }

local function truncate(text, limit)
  local length = utf8.len(text)
  if not length or length <= limit then
    return text
  end
  return text:sub(1, utf8.offset(text, limit + 1) - 1) .. "…"
end

return function(config, position, spacer)
  local limit = config.widget.last_command_max_length

  local color = {
    user = config.color.running_command,
    claude = config.color.running_command_claude,
  }

  local slot = {}

  local function build(source)
    local function make_icon()
      return common.add_icon(config, "running_command." .. source .. ".icon", position,
        icons.widget("running"), {
          drawing = false,
          icon = { font = common.icon_font(config, -4), color = color[source] },
        })
    end

    local function make_label()
      return common.add_label(config, "running_command." .. source .. ".label", position, {
        drawing = false,
        label = { string = "", color = color[source] },
      })
    end

    if position == "right" then
      local label, icon = make_label(), make_icon()
      return { icon = icon, label = label, shown = false }
    end
    local icon, label = make_icon(), make_label()
    return { icon = icon, label = label, shown = false }
  end

  for _, source in ipairs(SOURCES) do
    slot[source] = build(source)
  end

  sbar.add("event", "shell_running")

  local pulse_index = 1
  local animating = false

  local function any_shown()
    for _, source in ipairs(SOURCES) do
      if slot[source].shown then
        return true
      end
    end
    return false
  end

  local function tick()
    if not any_shown() then
      animating = false
      return
    end
    pulse_index = pulse_index % #PULSE + 1
    for _, source in ipairs(SOURCES) do
      if slot[source].shown then
        slot[source].icon:set({ icon = { color = util.alpha(color[source], PULSE[pulse_index]) } })
      end
    end
    sbar.delay(PULSE_INTERVAL, tick)
  end

  local group_shown

  local function render(source, command)
    local entry = slot[source]
    if not entry then
      return
    end

    local visible = command ~= nil and command ~= ""
    entry.shown = visible

    entry.icon:set({
      drawing = visible,
      icon = { color = util.alpha(color[source], PULSE[pulse_index]) },
    })
    entry.label:set({
      drawing = visible,
      label = { string = visible and truncate(command, limit) or "" },
    })

    local group = any_shown()
    if group_shown ~= group then
      common.set_group_visible("group_running_command", spacer, group)
      group_shown = group
    end

    if group and not animating then
      animating = true
      sbar.delay(PULSE_INTERVAL, tick)
    end
  end

  slot.user.label:subscribe("shell_running", function(env)
    render(env.SOURCE == "claude" and "claude" or "user", env.COMMAND)
  end)

  sbar.delay(0.1, function()
    render("user", nil)
    render("claude", nil)
  end)
end
