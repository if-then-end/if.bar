# if.bar

A Lua configuration for [sketchybar](https://github.com/FelixKratz/SketchyBar):
app icons, system status, weather, the command your shell is running, and one
indicator per live Claude Code session.

It runs as a single resident Lua process talking to sketchybar over kernel IPC,
so widgets update through event callbacks rather than by forking a shell.

## Install

Needs macOS and [Homebrew](https://brew.sh); the script pulls everything else.

```bash
curl -fsSL https://raw.githubusercontent.com/if-then-end/if.bar/main/scripts/install.sh | bash
```

It clones this repo into `~/.config/sketchybar`, moving any existing config to
`~/.config/sketchybar.backup.<timestamp>` first, then starts the bar.

<details>
<summary>Manual install</summary>

```bash
brew tap FelixKratz/formulae
brew install sketchybar jq lua
brew install --cask font-space-mono-nerd-font

git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua \
  && (cd /tmp/SbarLua && make install) && rm -rf /tmp/SbarLua

git clone https://github.com/if-then-end/if.bar ~/.config/sketchybar
```

App icons come from
[sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font). Build
it, then convert its icon list into the Lua table this config reads:

```bash
git clone https://github.com/kvndrsslr/sketchybar-app-font.git /tmp/app-font
cd /tmp/app-font && pnpm install && pnpm run build:install

awk -f ~/.config/sketchybar/scripts/icon_map_to_lua.awk dist/icon_map.sh \
  > ~/.config/sketchybar/lua/icons/apps.lua
cp dist/sketchybar-app-font.ttf ~/Library/Fonts/ && fc-cache -f

brew services restart sketchybar
```

</details>

[yabai](https://github.com/koekeishiya/yabai) is optional, and only the `space`
widget needs it.

## Configuration

```bash
cd ~/.config/sketchybar && cp ifbarrc.example ifbarrc
```

Every setting is listed and commented there. `ifbarrc` is parsed, not executed:
only `export NAME=value` lines count, and `$COLOR_*` resolves against the active
theme. Reload with `sketchybar --reload`.

Settings are named `IF_BAR_*`. The older `user.sketchybarrc` file and `SBAR_*`
prefix still work, and the new names win where both appear.

### Widgets

Three space-separated lists, in display order:

```bash
export IF_BAR_WIDGETS_LEFT_ENABLED="space claude running_command last_command"
export IF_BAR_WIDGETS_CENTER_ENABLED="front_app"
export IF_BAR_WIDGETS_RIGHT_ENABLED="clock weather caffeinate volume battery disk ram cpu"
```

`space` (yabai spaces with app icons) · `front_app` · `clock` · `calendar` ·
`weather` · `battery` · `disk` · `ram` · `cpu` · `netstat` · `volume` ·
`caffeinate` · `kakaotalk` · `last_command` · `running_command` · `claude`

Each list shares a rounded background. Spaces and the Claude icons stand alone
in their own, and the Claude group hides itself when no session is running.

### Themes

```bash
export IF_BAR_THEME="nord"
```

`onedark` (default), `nord`, `tokyonight`, `githubdark`, `gruvboxdark`,
`ayudark`, `onelight`, `githublight`, `gruvboxlight`, `blossomlight`, `ayulight`.

## Shell integration

`last_command` and `running_command` need a zsh hook. The shell reports the
command, so any terminal emulator works.

```zsh
ln -sf ~/.config/sketchybar/hooks/zsh-integration.zsh "$ZDOTDIR/functions/sketchybar.zsh"
echo 'source "$ZDOTDIR/functions/sketchybar.zsh"' >> "$ZDOTDIR/.zshrc"
```

A command reaches `running_command` only if it outlives `IF_BAR_RUNNING_DELAY`
(2s, exported from your `.zshrc`), and moves to `last_command` when it ends.

> **These widgets put your commands on screen.** The hook masks what looks like
> a secret — `password`, `token`, `authorization`, `bearer`, credentials in a
> URL, a password glued to `-p`, and similar — but it matches on keywords and is
> best effort, not a guarantee. Whatever gets through is visible to screen
> shares and screenshots. Leave both widgets out if that is not a trade you want.

## Claude Code integration

```bash
ln -sf ~/.config/sketchybar/hooks/claude-sessions.py \
  ~/.claude/hooks/sketchybar-claude-sessions.py
ln -sf ~/.config/sketchybar/hooks/claude-command.sh \
  ~/.claude/hooks/sketchybar-claude-command.sh
```

In `~/.claude/settings.json`, add
`python3 ~/.claude/hooks/sketchybar-claude-sessions.py` to `SessionStart`,
`SessionEnd`, `UserPromptSubmit`, `Stop` and `Notification`, and
`sh ~/.claude/hooks/sketchybar-claude-command.sh` to `PreToolUse` and
`PostToolUse` with a `Bash` matcher. Those arrays take more than one entry.

Each session gets a color, dimmed when idle, pulsing while Claude works, and
bright and steady when it is blocked on your answer. Commands Claude runs get
their own slot in `running_command`, so they never push out one of yours.

Both hooks swallow every error and exit 0, so a broken bar cannot disturb a
session. State lives in `~/.local/state/if.bar/`, created owner-only.

## Troubleshooting

| Symptom             | Check                                                      |
| ------------------- | ---------------------------------------------------------- |
| Icons show as boxes | `fc-list \| grep -i "space mono"`, then restart sketchybar |
| Spaces are empty    | `yabai -m query --spaces` — the widget needs yabai running |
| Weather is blank    | `curl -s "wttr.in/Seoul?format=j1"`                        |
| Bar does not start  | `lua ~/.config/sketchybar/sketchybarrc` shows the error    |

Update with `~/.config/sketchybar/scripts/update.sh`.

## Credits

[sketchybar](https://github.com/FelixKratz/SketchyBar) and
[SbarLua](https://github.com/FelixKratz/SbarLua) by FelixKratz ·
[sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) by
kvndrsslr

## License

MIT
