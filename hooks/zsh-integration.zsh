#!/usr/bin/env zsh

autoload -Uz add-zsh-hook

_sketchybar_bin() {
  local bin=/opt/homebrew/bin/sketchybar
  [[ -x "$bin" ]] && print -r -- "$bin" && return
  command -v sketchybar 2>/dev/null
}

_SKETCHYBAR_BIN="$(_sketchybar_bin)"
_SKETCHYBAR_RUNNING_DELAY=${SBAR_RUNNING_DELAY:-2}
_sketchybar_command=""
_sketchybar_timer=""

_sketchybar_mask() {
  local cmd="$1"
  case "${cmd:l}" in
    *password*|*passwd*|*passphrase*|*token*|*secret*|*api_key*|*apikey*|*credential*|*private_key*|*authorization*|*bearer*|*://*:*@*|*' -p'[a-zA-Z0-9]*)
      print -r -- "${cmd%% *} ***"
      ;;
    *)
      print -r -- "$cmd"
      ;;
  esac
}

_sketchybar_clean() {
  local quote="'"
  local text="${1//\"/$quote}"
  print -r -- "${text//\\/}"
}

_sketchybar_send() {
  [[ -n "$_SKETCHYBAR_BIN" ]] || return
  "$_SKETCHYBAR_BIN" --trigger shell_command \
    COMMAND="$(_sketchybar_clean "$1")" STATE="$2" >/dev/null 2>&1 &!
}

_sketchybar_send_running() {
  [[ -n "$_SKETCHYBAR_BIN" ]] || return
  "$_SKETCHYBAR_BIN" --trigger shell_running \
    COMMAND="$(_sketchybar_clean "$1")" >/dev/null 2>&1 &!
}

_sketchybar_preexec() {
  _sketchybar_command="$(_sketchybar_mask "$1")"

  local cmd="$_sketchybar_command"
  ( sleep "$_SKETCHYBAR_RUNNING_DELAY"; _sketchybar_send_running "$cmd" ) &!
  _sketchybar_timer=$!
}

_sketchybar_precmd() {
  local code=$?

  if [[ -n "$_sketchybar_timer" ]]; then
    kill "$_sketchybar_timer" 2>/dev/null
    _sketchybar_timer=""
  fi

  [[ -n "$_sketchybar_command" ]] || return

  _sketchybar_send_running ""

  local state=ok
  (( code != 0 )) && state=fail
  _sketchybar_send "$_sketchybar_command" "$state"
  _sketchybar_command=""
}

add-zsh-hook preexec _sketchybar_preexec
add-zsh-hook precmd _sketchybar_precmd
