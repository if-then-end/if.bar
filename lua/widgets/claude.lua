local common = require("widgets.common")
local icons = require("icons")
local util = require("util")

local STATE_PATH = (os.getenv("HOME") or "") .. "/.local/state/if.bar/claude-sessions"

local IDLE_ALPHA = 50
local PULSE = { 50, 75, 100, 75 }
local PULSE_INTERVAL = 0.2

local PALETTE = {
  "COLOR_GREEN",
  "COLOR_BLUE",
  "COLOR_MAGENTA",
  "COLOR_CYAN",
  "COLOR_ORANGE",
  "COLOR_YELLOW",
  "COLOR_RED",
  "COLOR_TANGERINE",
}

local function read_sessions()
  if not util.file_exists(STATE_PATH) then
    return {}
  end

  local ok, sessions = pcall(function()
    local out = {}
    for line in io.lines(STATE_PATH) do
      local pid, slot, state = line:match("^[^\t]*\t(%d+)\t(%d+)\t(%a+)$")
      if not pid then
        pid, slot = line:match("^[^\t]*\t(%d+)\t(%d+)$")
        state = "idle"
      end
      if pid then
        out[#out + 1] = { pid = tonumber(pid), slot = tonumber(slot), state = state }
      end
    end
    return out
  end)

  if not ok then
    return {}
  end
  return sessions
end

return function(cfg, position, spacer)
  local MAX_SLOTS = cfg.widget.claude_max_sessions
  local slots = {}

  for index = 1, MAX_SLOTS do
    slots[index] = common.add_icon(cfg, "claude." .. index, position, icons.app("Claude"), {
      drawing = false,
      icon = {
        font = cfg.font.app_icon .. ":Regular:" .. cfg.font.claude_icon_size,
        padding_left = index == 1 and cfg.item.icon_padding_left or 2,
        padding_right = 2,
      },
    })
  end

  local current = {}
  local pulse_index = 1
  local animating = false

  local function base_color(session)
    return cfg.colors[PALETTE[(session.slot % #PALETTE) + 1]] or cfg.color.default_icon
  end

  local function alpha_for(session, pulse)
    if session.state == "busy" then
      return pulse
    elseif session.state == "waiting" then
      return 100
    end
    return IDLE_ALPHA
  end

  local painted = {}
  local group_shown

  local function paint(pulse)
    local shown = #current > 0
    if group_shown ~= shown then
      common.set_group_visible("group_claude", spacer, shown)
      group_shown = shown
    end

    for index = 1, MAX_SLOTS do
      local session = current[index]
      local color = session and util.alpha(base_color(session), alpha_for(session, pulse))

      if painted[index] ~= color then
        if color then
          slots[index]:set({ drawing = true, icon = { color = color } })
        else
          slots[index]:set({ drawing = false })
        end
        painted[index] = color
      end
    end
  end

  local function has_busy()
    for _, session in ipairs(current) do
      if session.state == "busy" then
        return true
      end
    end
    return false
  end

  local function tick()
    if not has_busy() then
      animating = false
      paint(100)
      return
    end
    pulse_index = pulse_index % #PULSE + 1
    paint(PULSE[pulse_index])
    sbar.delay(PULSE_INTERVAL, tick)
  end

  local function apply(sessions)
    current = sessions
    if has_busy() then
      paint(PULSE[pulse_index])
      if not animating then
        animating = true
        sbar.delay(PULSE_INTERVAL, tick)
      end
    else
      paint(100)
    end
  end

  local function refresh()
    local sessions = read_sessions()

    if #sessions == 0 then
      apply({})
      return
    end

    local pids = {}
    for _, session in ipairs(sessions) do
      pids[#pids + 1] = tostring(session.pid)
    end

    sbar.exec("ps -p " .. table.concat(pids, ",") .. " -o pid= 2>/dev/null", function(result)
      local living = {}
      for pid in result:gmatch("%d+") do
        living[tonumber(pid)] = true
      end

      local alive = {}
      for _, session in ipairs(sessions) do
        if living[session.pid] then
          alive[#alive + 1] = session
        end
      end
      apply(alive)
    end)
  end

  sbar.add("event", "claude_sessions")

  slots[1]:subscribe("claude_sessions", refresh)
  slots[1]:subscribe({ "routine", "forced", "system_woke" }, refresh)
  slots[1]:set({ update_freq = cfg.freq.slow, updates = true })

  sbar.delay(0.1, refresh)
end
