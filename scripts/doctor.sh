#!/usr/bin/env bash

# Reports what is missing or wrong. Exits non-zero if anything is broken, so it
# can gate a script; warnings alone leave the exit code at zero.

if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  CONFIG_DIR="$HOME/.config/sketchybar"
fi

FONT_DIR="$HOME/Library/Fonts"
APP_FONT="$FONT_DIR/sketchybar-app-font.ttf"
MAP="$CONFIG_DIR/lua/icons/apps.lua"
STATE_DIR="$HOME/.local/state/if.bar"

failures=0
warnings=0

if [ -t 1 ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
  GREEN=""; YELLOW=""; RED=""; DIM=""; OFF=""
fi

section() { printf '\n%s%s%s\n' "$DIM" "$1" "$OFF"; }
ok()   { printf '  %sok%s    %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '  %swarn%s  %s\n' "$YELLOW" "$OFF" "$1"; warnings=$((warnings + 1)); }
fail() { printf '  %sfail%s  %s\n' "$RED" "$OFF" "$1"; failures=$((failures + 1)); }
note() { printf '        %s%s%s\n' "$DIM" "$1" "$OFF"; }

node_version_ok() {
  local bin="${1:-}" version major minor
  [ -n "$bin" ] && [ -x "$bin" ] || return 1
  version="$("$bin" -v 2>/dev/null)" || return 1
  version="${version#v}"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  [ "$major" -eq "$major" ] 2> /dev/null || return 1
  [ "$major" -gt 22 ] && return 0
  [ "$major" -eq 22 ] && [ "$minor" -ge 13 ] && return 0
  return 1
}

echo "if.bar doctor"
note "$CONFIG_DIR"

section "Dependencies"

if command -v sketchybar > /dev/null; then
  ok "sketchybar $(sketchybar --version 2>/dev/null | head -1)"
else
  fail "sketchybar not installed (brew install FelixKratz/formulae/sketchybar)"
fi

command -v lua > /dev/null && ok "lua" || fail "lua not installed (brew install lua)"

if [ -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]; then
  ok "SbarLua"
else
  fail "SbarLua missing - the bar cannot start without it"
  note "github.com/FelixKratz/SbarLua"
fi

command -v jq > /dev/null && ok "jq" \
  || warn "jq missing - the space and weather widgets need it"

if command -v pnpm > /dev/null; then
  ok "pnpm"
else
  warn "pnpm missing - only update-app-font.sh needs it"
fi

if node_version_ok "$(command -v node || true)"; then
  ok "node $(node -v)"
else
  usable=""
  for candidate in "$(brew --prefix node 2> /dev/null)/bin/node" /opt/homebrew/bin/node; do
    if node_version_ok "$candidate"; then
      usable="$candidate"
      break
    fi
  done
  if [ -n "$usable" ]; then
    ok "node $("$usable" -v) at $(dirname "$usable")"
    note "not first on PATH; update-app-font.sh looks past the one that is"
  else
    warn "no node >= 22.13 - only update-app-font.sh needs it"
  fi
fi

section "Fonts"

if [ -s "$APP_FONT" ]; then
  ok "sketchybar-app-font"
else
  fail "sketchybar-app-font missing - app icons render as text like :ghostty:"
  note "$CONFIG_DIR/scripts/update-app-font.sh"
fi

if compgen -G "$FONT_DIR/*NerdFont*" > /dev/null || compgen -G "/Library/Fonts/*NerdFont*" > /dev/null; then
  ok "a Nerd Font is installed"
else
  warn "no Nerd Font found - widget icons render as boxes"
  note "brew install --cask font-space-mono-nerd-font"
fi

# The map holds ligature names the font turns into glyphs, so a name the font
# does not carry reaches the bar as literal text. They only match when both came
# from the same build.
if [ -s "$APP_FONT" ] && [ -f "$MAP" ] && command -v python3 > /dev/null; then
  missing="$(python3 - "$APP_FONT" "$MAP" <<'PYCHECK'
import re, struct, sys

font, mapping = sys.argv[1], sys.argv[2]
data = open(font, "rb").read()
tables = {}
for i in range(struct.unpack(">H", data[4:6])[0]):
    o = 12 + 16 * i
    tables[data[o:o + 4].decode("latin1")] = struct.unpack(">II", data[o + 8:o + 16])

offset, length = tables["post"]
if struct.unpack(">I", data[offset:offset + 4])[0] != 0x00020000:
    sys.exit(0)

count = struct.unpack(">H", data[offset + 32:offset + 34])[0]
indices = struct.unpack(">%dH" % count, data[offset + 34:offset + 34 + 2 * count])
pos, end, pascal = offset + 34 + 2 * count, offset + length, []
while pos < end:
    size = data[pos]
    pascal.append(data[pos + 1:pos + 1 + size].decode("latin1"))
    pos += 1 + size

glyphs = {pascal[i - 258] for i in indices if i >= 258}
missing = sorted(set(re.findall(r'"(:[a-z0-9_]+:)"', open(mapping).read())) - glyphs)
print(" ".join(missing[:6]))
PYCHECK
)"
  if [ -z "$missing" ]; then
    ok "icon map matches the installed font"
  else
    fail "icon map references glyphs the font lacks: $missing"
    note "rebuild both together: $CONFIG_DIR/scripts/update-app-font.sh"
  fi
fi

section "Configuration"

if [ -f "$CONFIG_DIR/ifbarrc" ]; then
  ok "reading ifbarrc"
elif [ -f "$CONFIG_DIR/user.sketchybarrc" ]; then
  ok "reading user.sketchybarrc"
  note "the current name is ifbarrc; this one is read only when it is absent"
  if grep -q '^[[:space:]]*\(export[[:space:]]\+\)\?SBAR_' "$CONFIG_DIR/user.sketchybarrc"; then
    warn "settings still use the SBAR_ prefix - mapped on read, but IF_BAR_ is current"
  fi
else
  ok "no config file - running on the defaults in lua/config.lua"
  note "cp ifbarrc.example ifbarrc to change anything"
fi

broken=""
for file in "$CONFIG_DIR/sketchybarrc" "$CONFIG_DIR"/lua/*.lua "$CONFIG_DIR"/lua/*/*.lua; do
  [ -f "$file" ] || continue
  if command -v luac > /dev/null; then
    luac -p "$file" > /dev/null 2>&1 || broken="$broken ${file#"$CONFIG_DIR"/}"
  else
    lua -e "assert(loadfile('$file'))" > /dev/null 2>&1 || broken="$broken ${file#"$CONFIG_DIR"/}"
  fi
done
[ -z "$broken" ] && ok "every Lua file parses" || fail "does not parse:$broken"

if [ -d "$STATE_DIR" ]; then
  mode="$(stat -f '%OLp' "$STATE_DIR")"
  [ "$mode" = "700" ] && ok "state directory is owner-only" \
    || warn "state directory is $mode, expected 700 - $STATE_DIR"
fi

section "Runtime"

if pgrep -x sketchybar > /dev/null; then
  daemon="$(pgrep -x sketchybar | head -1)"
  ok "sketchybar running (pid $daemon)"

  configs="$(ps -eo pid,ppid,command | awk -v d="$daemon" '$2 == d && /lua .*sketchybarrc/' | wc -l | tr -d ' ')"
  case "$configs" in
    1) ok "one config process" ;;
    0) fail "no config process - the bar is empty until sketchybar --reload" ;;
    *) warn "$configs config processes - each runs its own event loop" ;;
  esac

  if command -v python3 > /dev/null; then
    items="$(sketchybar --query bar 2> /dev/null \
      | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("items", [])))' 2> /dev/null)"
    if [ "${items:-0}" -gt 0 ]; then
      ok "$items items on the bar"
    else
      fail "no items on the bar - try sketchybar --reload"
    fi
  fi
else
  fail "sketchybar not running (brew services start sketchybar)"
fi

section "Optional"

if command -v yabai > /dev/null; then
  if ! pgrep -x yabai > /dev/null; then
    warn "yabai installed but not running - the space widget falls back to one space"
  elif yabai -m query --spaces 2>/dev/null | grep -q '"index"'; then
    ok "yabai answers space queries"
  else
    warn "yabai runs but --spaces returns nothing - try yabai --restart-service"
    note "the space widget builds its items from that query at load"
  fi
else
  note "yabai not installed - only the space widget uses it"
fi

section "Summary"
if [ "$failures" -gt 0 ]; then
  printf '  %s%d broken%s, %d warning(s)\n' "$RED" "$failures" "$OFF" "$warnings"
  exit 1
fi
if [ "$warnings" -gt 0 ]; then
  printf '  %s%d warning(s)%s, nothing broken\n' "$YELLOW" "$warnings" "$OFF"
  exit 0
fi
printf '  %sall clear%s\n' "$GREEN" "$OFF"
