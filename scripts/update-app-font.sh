#!/usr/bin/env bash

set -euo pipefail

UPSTREAM="https://github.com/kvndrsslr/sketchybar-app-font.git"
REF="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

AWK_SCRIPT="$SCRIPT_DIR/icon_map_to_lua.awk"
OVERLAY="$CONFIG_DIR/app-font"
# The digest of the last build's overrides. Runtime state, not repo content:
# overrides are local, and the map they would otherwise stamp is committed.
OVERLAY_STATE="$HOME/.local/state/if.bar/app-font-overlay"
MAP="$CONFIG_DIR/lua/icons/apps.lua"
FONT="$HOME/Library/Fonts/sketchybar-app-font.ttf"

die() {
  echo "Error: $*" >&2
  exit 1
}

node_version_ok() {
  local bin="${1:-}" version major minor
  [ -n "$bin" ] && [ -x "$bin" ] || return 1
  version="$("$bin" -v 2>/dev/null)" || return 1
  version="${version#v}"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  [ "$major" -eq "$major" ] 2>/dev/null || return 1
  [ "$major" -gt 22 ] && return 0
  [ "$major" -eq 22 ] && [ "$minor" -ge 13 ] && return 0
  return 1
}

keys_of() {
  grep -o '^[[:space:]]*\["[^"]*"\]' "$1" | sed 's/.*\["//; s/"\]$//' | sort
}

# The upstream commit the map was built from, recorded in its first line.
recorded_commit() {
  sed -n '1s/.*font@\([0-9a-f]*\).*/\1/p' "$1"
}

# Only what reaches the font counts, and by path relative to the overlay, so
# neither a note kept alongside nor moving the checkout forces a rebuild.
overlay_digest() {
  local files
  files="$(cd "$OVERLAY" 2> /dev/null \
    && find svgs -type f -name '*.svg' 2> /dev/null \
    && find mappings -type f ! -name '.*' ! -name '*.*' 2> /dev/null)"
  files="$(printf '%s' "$files" | sort)"
  if [ -z "$files" ]; then
    echo "none"
    return
  fi
  {
    echo "$files"
    printf '%s' "$files" | tr '\n' '\0' | (cd "$OVERLAY" && xargs -0 cat)
  } | md5
}

[ -f "$AWK_SCRIPT" ] || die "generator not found: $AWK_SCRIPT"
[ -f "$MAP" ] || die "icon map not found: $MAP"
command -v git > /dev/null || die "git is required"

CURRENT="$(recorded_commit "$MAP")"
OVERLAY_NOW="$(overlay_digest)"

# A font build is not byte-reproducible, so being up to date is decided by the
# upstream commit - and ls-remote answers that without cloning or building.
if [ -z "$REF" ] && [ -n "$CURRENT" ] && [ -s "$FONT" ] \
  && [ "$(cat "$OVERLAY_STATE" 2> /dev/null)" = "$OVERLAY_NOW" ]; then
  REMOTE="$(git ls-remote "$UPSTREAM" HEAD 2> /dev/null | cut -f1)"
  if [ -n "$REMOTE" ] && [ "$REMOTE" = "$CURRENT" ]; then
    echo "Already up to date ($(keys_of "$MAP" | wc -l | tr -d ' ') apps, upstream ${CURRENT:0:7})"
    exit 0
  fi
fi

command -v pnpm > /dev/null || die "pnpm is required (brew install pnpm)"

# pnpm refuses to run on older Node, and an outdated /usr/local/bin/node
# often shadows the current one.
if ! node_version_ok "$(command -v node || true)"; then
  for candidate in \
    "$(brew --prefix node 2> /dev/null)/bin/node" \
    /opt/homebrew/bin/node \
    /usr/local/opt/node/bin/node
  do
    if node_version_ok "$candidate"; then
      PATH="$(dirname "$candidate"):$PATH"
      echo "Using Node $("$candidate" -v) from $(dirname "$candidate")"
      break
    fi
  done
fi
node_version_ok "$(command -v node || true)" \
  || die "pnpm needs Node >= 22.13, found $(node -v 2> /dev/null || echo none)"

TMP="$(mktemp -d)"
LOG="$TMP/build.log"
trap 'rm -rf "$TMP"' EXIT

echo "Cloning $UPSTREAM${REF:+ @ $REF}..."
if [ -n "$REF" ]; then
  git clone -q "$UPSTREAM" "$TMP/font" || die "clone failed"
  git -C "$TMP/font" checkout -q "$REF" || die "no such ref: $REF"
else
  git clone -q --depth 1 "$UPSTREAM" "$TMP/font" || die "clone failed"
fi

COMMIT_FULL="$(git -C "$TMP/font" rev-parse HEAD)"
COMMIT="${COMMIT_FULL:0:7}"
COMMIT_DATE="$(git -C "$TMP/font" log -1 --format=%cs)"
echo "  at $COMMIT ($COMMIT_DATE)"

# Applied to the clone rather than kept as a patch, so an upstream refresh keeps
# them: svgtofont names each glyph after its file, and an SVG with no mapping is
# only an informational note to the upstream validator.
# Only glyphs and mappings, never a note kept alongside them: the upstream
# validator runs isSvg() over every file in svgs/ and exits on the first that
# is not one.
APPLIED=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  cp "$OVERLAY/$rel" "$TMP/font/$rel"
  echo "  override $rel"
  APPLIED=$((APPLIED + 1))
done <<EOF
$(cd "$OVERLAY" 2> /dev/null \
  && find svgs -type f -name '*.svg' 2> /dev/null \
  && find mappings -type f ! -name '.*' ! -name '*.*' 2> /dev/null)
EOF
[ "$APPLIED" -gt 0 ] && echo "  $APPLIED local override(s) applied"

echo "Building the font (this pulls the upstream dev dependencies)..."
if ! (cd "$TMP/font" && pnpm install && pnpm run build) > "$LOG" 2>&1; then
  echo "--- last 20 lines of the build log ---" >&2
  tail -20 "$LOG" >&2
  die "build failed"
fi

BUILT_FONT="$TMP/font/dist/sketchybar-app-font.ttf"
BUILT_MAP="$TMP/font/dist/icon_map.sh"
[ -s "$BUILT_FONT" ] || die "build produced no font"
[ -s "$BUILT_MAP" ] || die "build produced no icon map"

echo "Converting the icon map to Lua..."
{
  echo "-- generated by scripts/$(basename "$0") from kvndrsslr/sketchybar-app-font@$COMMIT_FULL"
  awk -f "$AWK_SCRIPT" "$BUILT_MAP"
} > "$TMP/apps.lua" || die "conversion failed"

# A silently mangled map would leave every app on the default glyph, so the
# generated file has to load and carry a plausible number of entries.
if command -v luac > /dev/null; then
  luac -p "$TMP/apps.lua" || die "generated map is not valid Lua"
fi
NEW_COUNT="$(keys_of "$TMP/apps.lua" | wc -l | tr -d ' ')"
[ "$NEW_COUNT" -ge 100 ] || die "generated map has only $NEW_COUNT entries, refusing to install"
grep -q '^  default = "' "$TMP/apps.lua" || die "generated map has no default glyph"

# The map and the font are only interchangeable when they come from one build:
# a name the font has no glyph for renders as literal text like ":ghostty:".
if command -v python3 > /dev/null; then
  python3 - "$BUILT_FONT" "$TMP/apps.lua" <<'PYCHECK' || die "map references glyphs the font does not have"
import re, struct, sys

font, mapping = sys.argv[1], sys.argv[2]
data = open(font, "rb").read()
tables = {}
for i in range(struct.unpack(">H", data[4:6])[0]):
    o = 12 + 16 * i
    tables[data[o:o + 4].decode("latin1")] = struct.unpack(">II", data[o + 8:o + 16])

offset, length = tables["post"]
if struct.unpack(">I", data[offset:offset + 4])[0] != 0x00020000:
    sys.exit(0)  # no glyph names to check against

count = struct.unpack(">H", data[offset + 32:offset + 34])[0]
indices = struct.unpack(">%dH" % count, data[offset + 34:offset + 34 + 2 * count])
pos, end, pascal = offset + 34 + 2 * count, offset + length, []
while pos < end:
    size = data[pos]
    pascal.append(data[pos + 1:pos + 1 + size].decode("latin1"))
    pos += 1 + size

glyphs = {pascal[i - 258] for i in indices if i >= 258}
missing = sorted(set(re.findall(r'"(:[a-z0-9_]+:)"', open(mapping).read())) - glyphs)
if missing:
    print("missing glyphs: " + " ".join(missing[:10]), file=sys.stderr)
    sys.exit(1)
PYCHECK
fi

OLD_COUNT="$(keys_of "$MAP" | wc -l | tr -d ' ')"

keys_of "$MAP" > "$TMP/old.keys"
keys_of "$TMP/apps.lua" > "$TMP/new.keys"

echo "Installing..."
mv "$TMP/apps.lua" "$MAP"
mkdir -p "$(dirname "$OVERLAY_STATE")"
printf '%s\n' "$OVERLAY_NOW" > "$OVERLAY_STATE"
mkdir -p "$(dirname "$FONT")"
cp "$BUILT_FONT" "$FONT"

command -v fc-cache > /dev/null && fc-cache -f "$(dirname "$FONT")" > /dev/null 2>&1 || true
pgrep -x sketchybar > /dev/null && sketchybar --reload || true

ADDED="$(comm -13 "$TMP/old.keys" "$TMP/new.keys" | wc -l | tr -d ' ')"
REMOVED="$(comm -23 "$TMP/old.keys" "$TMP/new.keys" | wc -l | tr -d ' ')"

echo ""
echo "Updated to $COMMIT ($COMMIT_DATE)"
echo "  apps: $OLD_COUNT -> $NEW_COUNT (+$ADDED, -$REMOVED)"
if [ "$ADDED" -gt 0 ]; then
  echo "  added:   $(comm -13 "$TMP/old.keys" "$TMP/new.keys" | head -12 | paste -sd ' ' -)$([ "$ADDED" -gt 12 ] && echo " ...")"
fi
if [ "$REMOVED" -gt 0 ]; then
  echo "  removed: $(comm -23 "$TMP/old.keys" "$TMP/new.keys" | head -12 | paste -sd ' ' -)$([ "$REMOVED" -gt 12 ] && echo " ...")"
fi
echo ""
echo "To rebuild this exact set later: $(basename "$0") $COMMIT"
