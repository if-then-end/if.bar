local common = require("widgets.common")
local icons = require("icons")

local FAIL_GLYPH = "✗"

local function truncate(text, limit)
  local length = utf8.len(text)
  if not length or length <= limit then
    return text
  end
  return text:sub(1, utf8.offset(text, limit + 1) - 1) .. "…"
end

return function(cfg, position)
  local limit = cfg.widget.last_command_max_length

  local function make_icon()
    return common.add_icon(cfg, "last_command.icon", position, icons.app("Terminal"), {
      icon = {
        font = cfg.font.app_icon .. ":Regular:" .. cfg.font.app_icon_size,
        color = cfg.color.last_command,
        padding_right = cfg.item.icon_padding_right,
      },
    })
  end

  local function make_label()
    return common.add_label(cfg, "last_command.label", position, {
      label = { string = "", padding_right = 4 },
    })
  end

  local function make_state()
    return common.add_icon(cfg, "last_command.state", position, FAIL_GLYPH, {
      icon = {
        font = common.icon_font(cfg, -6),
        padding_left = 0,
        padding_right = cfg.item.label_padding_right,
      },
    })
  end

  local icon, label, state
  if position == "right" then
    state, label, icon = make_state(), make_label(), make_icon()
  else
    icon, label, state = make_icon(), make_label(), make_state()
  end

  sbar.add("event", "shell_command")

  local function render(command, status)
    if not command or command == "" then
      icon:set({ drawing = false })
      label:set({ drawing = false })
      state:set({ drawing = false })
      return
    end

    local color = cfg.color.last_command
    if status == "fail" then
      color = cfg.color.last_command_error
    elseif status == "claude" then
      color = cfg.color.last_command_claude
    end

    local failed = status == "fail"

    icon:set({ drawing = true })
    label:set({
      drawing = true,
      label = {
        string = truncate(command, limit),
        color = color,
        padding_right = failed and 4 or cfg.item.label_padding_right,
      },
    })
    state:set({
      drawing = failed,
      icon = { string = FAIL_GLYPH, color = color },
    })
  end

  label:subscribe("shell_command", function(env)
    render(env.COMMAND, env.STATE)
  end)

  render(nil, nil)
end
