# if.bar

A Lua configuration for [sketchybar](https://github.com/FelixKratz/SketchyBar):
app icons, system status, weather, the command your shell is running, and one
indicator per live Claude Code session.

It runs as a single resident Lua process talking to sketchybar over kernel IPC,
so widgets update through event callbacks rather than by forking a shell on a
timer.

## Requirements

macOS with [Homebrew](https://brew.sh). The installer pulls the rest:
sketchybar, [SbarLua](https://github.com/FelixKratz/SbarLua), lua, jq, pnpm,
Space Mono Nerd Font and
[sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font).

[yabai](https://github.com/koekeishiya/yabai) is optional and only needed for
the `space` widget.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/if-then-end/if.bar/main/scripts/install.sh | bash
```

It installs the dependencies, clones this repo into `~/.config/sketchybar`,
generates the app icon map and starts the bar. An existing config directory is
moved to `~/.config/sketchybar.backup.<timestamp>` first.

<details>
<summary>Manual install</summary>

```bash
brew tap FelixKratz/formulae
brew install sketchybar jq lua
brew install --cask font-space-mono-nerd-font

git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua \
  && (cd /tmp/SbarLua && make install) \
  && rm -rf /tmp/SbarLua

git clone https://github.com/if-then-end/if.bar ~/.config/sketchybar
```

Then build the app icon map, which turns the upstream icon list into the Lua
table this config reads:

```bash
git clone https://github.com/kvndrsslr/sketchybar-app-font.git /tmp/app-font
cd /tmp/app-font && pnpm install && pnpm run build:install

awk -f ~/.config/sketchybar/scripts/icon_map_to_lua.awk dist/icon_map.sh \
  > ~/.config/sketchybar/lua/icons/apps.lua
cp dist/sketchybar-app-font.ttf ~/Library/Fonts/
fc-cache -f

brew services restart sketchybar
```

</details>

## Configuration

```bash
cd ~/.config/sketchybar
cp ifbarrc.example ifbarrc
```

`ifbarrc` is parsed, not executed: only `export NAME=value` lines count, and
`$COLOR_*` names resolve against the active theme. Every supported setting is
listed and commented in `ifbarrc.example`; anything you leave out falls back to
the defaults in `lua/config.lua`. Reload with `sketchybar --reload`.

Settings are named `IF_BAR_*`. The older `user.sketchybarrc` file and the
`SBAR_*` prefix are both still accepted, so an existing setup keeps working;
the new names win where a file has both.

### Widgets

Three space-separated lists, in display order:

```bash
export IF_BAR_WIDGETS_LEFT_ENABLED="space claude running_command last_command"
export IF_BAR_WIDGETS_CENTER_ENABLED="front_app"
export IF_BAR_WIDGETS_RIGHT_ENABLED="clock weather caffeinate volume battery disk ram cpu"
```

| Widget | Shows |
| --- | --- |
| `space` | yabai spaces with the icons of the apps in them |
| `front_app` | The focused application |
| `clock`, `calendar` | Time and date, formats configurable |
| `weather` | Current conditions for `IF_BAR_WEATHER_LOCATION` |
| `battery`, `disk`, `ram`, `cpu` | System status, with optional graphs |
| `netstat` | Network throughput |
| `volume` | Output volume; click to mute |
| `caffeinate` | Click to keep the display awake |
| `kakaotalk` | Whether KakaoTalk is running; click to open it |
| `last_command` | The last shell command that finished, and whether it failed |
| `running_command` | A command still running |
| `claude` | One icon per live Claude Code session |

Widgets are grouped into left, center and right containers sharing a rounded
background. Spaces and the Claude icons stand alone in their own background,
separated by a wider gap; the Claude group hides itself when no session is up.

### Themes

```bash
export IF_BAR_THEME="nord"
```

Dark: `onedark` (default), `nord`, `tokyonight`, `githubdark`, `gruvboxdark`,
`ayudark`. Light: `onelight`, `githublight`, `gruvboxlight`, `blossomlight`,
`ayulight`.

## Shell integration

`last_command` and `running_command` need a zsh hook. It reports the command
itself, so it works with any terminal emulator:

```zsh
ln -sf ~/.config/sketchybar/hooks/zsh-integration.zsh "$ZDOTDIR/functions/sketchybar.zsh"
echo 'source "$ZDOTDIR/functions/sketchybar.zsh"' >> "$ZDOTDIR/.zshrc"
```

A command that finishes quickly never reaches `running_command`; only one that
outlives `IF_BAR_RUNNING_DELAY` (2s) does. `last_command` then shows it once it is
done. Long commands are cut at `IF_BAR_LAST_COMMAND_MAX_LENGTH` characters —
characters, not bytes, so a Korean command is not cut mid-glyph.

> **These widgets put your commands on screen.** The hook masks what looks like
> a secret — `password`, `passphrase`, `token`, `secret`, `api_key`,
> `credential`, `private_key`, `authorization`, `bearer`, a `user:pass@host` URL,
> or a password glued to `-p` — but that filter matches on keywords and is best
> effort, not a guarantee. Anything that gets through is visible to screen
> shares, screenshots and whoever is behind you. Leave both widgets out of the
> list if that is not a trade you want.

Only your shell and Claude are reported; scripts and cron jobs stay invisible.
Terminal windows share one slot, so with several open the most recent wins.

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
`PostToolUse` with a `Bash` matcher. These arrays take more than one entry, so
add them alongside any hooks you already have.

Each session gets its own color, and its icon reflects what the session is
doing:

| State | Look | Meaning |
| --- | --- | --- |
| Idle | Dimmed | The turn ended, nothing pending |
| Answering | Pulsing | Claude is working |
| Waiting for you | Bright, steady | Claude is blocked on an answer |

Commands Claude runs land in `running_command` in their own slot, so they never
push out one of yours. Both hooks swallow every error and exit 0, so a broken
bar cannot disturb a session, and sessions killed without firing `SessionEnd`
drop off once their pid is gone.

State that has to survive a run — session ids, pids — lives in
`~/.local/state/if.bar/`, created owner-only so other accounts on the machine
cannot read it.

## Update

```bash
~/.config/sketchybar/scripts/update.sh
```

Or `git pull origin main && sketchybar --reload`.

## Troubleshooting

**Icons are missing or show as boxes.** Check the fonts landed, then restart:

```bash
fc-list | grep -i "space mono"
fc-list | grep -i "sketchybar-app-font"
brew services restart sketchybar
```

**Spaces are empty.** The `space` widget needs yabai running:

```bash
brew services list | grep yabai
yabai -m query --spaces
```

**Weather is blank.** It reads from wttr.in:

```bash
curl -s "wttr.in/Seoul?format=j1"
```

**The bar does not start.** Run the config by hand to see the error:

```bash
lua ~/.config/sketchybar/sketchybarrc
```

## Credits

- [sketchybar](https://github.com/FelixKratz/SketchyBar) and
  [SbarLua](https://github.com/FelixKratz/SbarLua) by FelixKratz
- [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) by kvndrsslr

## License

MIT
