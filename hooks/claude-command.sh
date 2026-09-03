#!/bin/sh
# Report the Bash command Claude is running.
# PreToolUse shows it, PostToolUse clears it. Always exits 0.

payload=$(cat 2>/dev/null)
[ -n "$payload" ] || exit 0

sb=/opt/homebrew/bin/sketchybar
[ -x "$sb" ] || sb=$(command -v sketchybar 2>/dev/null)
[ -n "$sb" ] || exit 0

event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)

if [ "$event" = "PostToolUse" ]; then
  "$sb" --trigger shell_running COMMAND= SOURCE=claude >/dev/null 2>&1 &
  exit 0
fi

cmd=$(printf '%s' "$payload" | jq -r 'select(.tool_name=="Bash") | .tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

cmd=$(printf '%s' "$cmd" | tr '\n\t"' "  '" | tr -d '\\' | tr -s ' ')
case "$(printf '%s' "$cmd" | tr 'A-Z' 'a-z')" in
  *password*|*passwd*|*passphrase*|*token*|*secret*|*api_key*|*apikey*|*credential*|*private_key*|*authorization*|*bearer*|*://*:*@*|*' -p'[a-zA-Z0-9]*)
    cmd="${cmd%% *} ***" ;;
esac

"$sb" --trigger shell_running COMMAND="$cmd" SOURCE=claude >/dev/null 2>&1 &
exit 0
