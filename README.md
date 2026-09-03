<img width="2304" height="1296" alt="스크린샷 2025-11-04 17 23 49" src="https://github.com/user-attachments/assets/e5261c54-6243-4e9c-9610-eaf105cfd28e" />

# if.bar

A customized macOS menu bar configuration featuring app icons, system status, weather, and more.

Everything is configured through environment variables in a single file,
`~/.config/sketchybar/user.sketchybarrc`. See [Configuration](#configuration).

## Dependencies

### Required

- [Homebrew](https://brew.sh/) - Package manager for macOS
- [sketchybar](https://github.com/FelixKratz/SketchyBar) - Customizable status bar
- [SbarLua](https://github.com/FelixKratz/SbarLua) - Lua API for sketchybar
- [lua](https://www.lua.org/) - Runs the configuration
- [jq](https://stedolan.github.io/jq/) - JSON processor
- [pnpm](https://pnpm.io/) - Package manager
- [Space Mono Nerd Font](https://www.nerdfonts.com/) - Font with icons
- [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) - App icon font

### Optional

- [yabai](https://github.com/koekeishiya/yabai) - Window manager (for workspace features)

## Installation

### Quick Install (Recommended)

Install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/if-then-end/if.bar/main/scripts/install.sh | bash
```

### Manual Installation

#### 1. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install Required Packages

```bash
brew tap FelixKratz/formulae
brew install sketchybar jq lua

# Lua bindings for sketchybar
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua \
  && (cd /tmp/SbarLua && make install) \
  && rm -rf /tmp/SbarLua
brew install --cask font-space-mono-nerd-font
```

#### 3. (Optional) Install Window Manager

For workspace/space features, install yabai:

```bash
brew install koekeishiya/formulae/yabai
brew services start yabai
```

#### 4. Clone Configuration

```bash
# Backup existing config (if any)
mv ~/.config/sketchybar ~/.config/sketchybar.backup

# Clone this configuration
git clone https://github.com/if-then-end/if.bar ~/.config/sketchybar
```

#### 5. Install App Icon Font

```bash
cd /tmp
git clone https://github.com/kvndrsslr/sketchybar-app-font.git
cd sketchybar-app-font
pnpm install
pnpm run build:install
```

Then convert the icon map into the Lua table the config reads, and install the
font:

```bash
mkdir -p ~/.config/sketchybar/lua/icons
awk -f ~/.config/sketchybar/scripts/icon_map_to_lua.awk dist/icon_map.sh \
  > ~/.config/sketchybar/lua/icons/apps.lua
cp dist/sketchybar-app-font.ttf ~/Library/Fonts/
fc-cache -f
```

#### 6. Start Sketchybar

```bash
brew services restart sketchybar
```

Done! You should now see the customized status bar at the top of your screen.

## Update

### Quick Update (Recommended)

Update to the latest version with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/if-then-end/if.bar/main/scripts/update.sh | bash
```

Or specify a custom directory:

```bash
curl -fsSL https://raw.githubusercontent.com/if-then-end/if.bar/main/scripts/update.sh | bash -s /path/to/sketchybar
```

### Manual Update

Navigate to your sketchybar config directory and run the update script:

```bash
cd ~/.config/sketchybar
./scripts/update.sh
```

Or specify a custom directory:

```bash
./scripts/update.sh /path/to/sketchybar
```

Or use git directly:

```bash
cd ~/.config/sketchybar
git pull origin main
brew services restart sketchybar
```

## Structure

The configuration runs as a single resident Lua process that talks to
sketchybar over kernel IPC, so widgets update through event callbacks rather
than by forking a shell on a timer.

```
sketchybarrc          Lua entry point
lua/
  config.lua          Reads user.sketchybarrc, applies defaults
  theme.lua           Theme loading and alpha variants
  themes/             One file per theme
  icons.lua           Icon lookup (app, widget, weather)
  icons/              Generated icon maps
  loader.lua          Builds widgets, tracks created items
  styles.lua          Colors and container brackets
  widgets/            One file per widget
hooks/                Shell and Claude Code integrations
scripts/              Install and update
```

Widgets that need to remember something between runs keep it under
`~/.local/state/if.bar/`, a directory created with owner-only permissions so
session ids and pids are not readable by other accounts on the machine.

## Configuration

### User Configuration

Create a user config file to override defaults:

```bash
# Create user config
touch ~/.config/sketchybar/user.sketchybarrc
```

Edit `user.sketchybarrc` to customize settings:

```bash
# Theme
export SBAR_THEME="onedark"  # or "onelight"

# Font settings
export SBAR_LABEL_FONT_FAMILY="SpaceMono Nerd Font Mono"
export SBAR_ICON_FONT_SIZE="18.0"
export SBAR_LABEL_FONT_SIZE="12.0"
export SBAR_APP_ICON_FONT_SIZE="13.5"

# Bar settings
export SBAR_BAR_HEIGHT=56
export SBAR_BAR_POSITION="top"  # top or bottom
export SBAR_BAR_BACKGROUND="transparent"  # or "bg1"

# Update frequency
export SBAR_ITEM_UPDATE_FREQ_FAST=2
export SBAR_ITEM_UPDATE_FREQ_DEFAULT=10
export SBAR_ITEM_UPDATE_FREQ_SLOW=30

# Weather location
export SBAR_WEATHER_LOCATION="Seoul"
```

### Enable/Disable Widgets

Set the widget lists in `user.sketchybarrc`. Each is a space-separated string:

```bash
export SBAR_WIDGETS_LEFT_ENABLED="space"
export SBAR_WIDGETS_CENTER_ENABLED="front_app"
export SBAR_WIDGETS_RIGHT_ENABLED="clock calendar weather battery ram cpu volume"
```

Available widgets: `space`, `front_app`, `clock`, `calendar`, `weather`,
`caffeinate`, `volume`, `battery`, `disk`, `ram`, `cpu`, `netstat`,
`kakaotalk`, `last_command`, `running_command`, `claude`.

Leaving a variable unset falls back to the defaults in `lua/config.lua`.

### Last Shell Command

The `last_command` widget shows the command you last ran in a terminal, with a
check or cross once it finishes. It reads nothing from the terminal app itself,
so it works with Ghostty, kitty, WezTerm and anything else — the shell reports
the command instead.

The integration lives in `hooks/`. Link it into your zsh config and source it
(adjust the path if you do not use `$ZDOTDIR`):

```zsh
ln -sf ~/.config/sketchybar/hooks/zsh-integration.zsh "$ZDOTDIR/functions/sketchybar.zsh"
echo 'source "$ZDOTDIR/functions/sketchybar.zsh"' >> "$ZDOTDIR/.zshrc"
```

The hook masks commands that look like they carry a secret — `password`,
`passphrase`, `token`, `secret`, `api_key`, `credential`, `private_key`,
`authorization`, `bearer`, a `user:password@host` URL, or a password glued to
`-p` — and shows only the command name.

That filter matches on keywords, so treat it as best effort rather than a
guarantee: a secret passed under an unusual flag still reaches the bar. Whatever
survives is on screen, which means screen shares, screenshots and anyone behind
you see it too. Leave `last_command` and `running_command` out of the widget
list if that is not a trade you want to make.

Commands Claude runs appear too, in their own color, through a PreToolUse
hook on Bash — the shell hook cannot see them, since Claude runs commands in a
non-interactive shell where preexec never fires. Both share one widget, so a
burst of tool calls pushes out what you last typed.

Beyond those two, nothing is reported: scripts, cron jobs and other tools stay
invisible. The widget does not distinguish terminal windows either, so with
several open the most recent command wins.

Long commands are cut at SBAR_LAST_COMMAND_MAX_LENGTH characters (60 by
default), counted as characters rather than bytes so a Korean command is not
cut mid-glyph.

Double quotes are rewritten as single quotes before the command is sent.
sketchybar drops an event argument containing a double quote, which would
otherwise blank the widget on something as ordinary as git commit -m "msg".

### Running Command

The `running_command` widget shows a command that is still going. A command
that finishes quickly never appears there; only one that outlives
`SBAR_RUNNING_DELAY` (2 seconds by default) does, and it clears when the
command ends.

preexec cannot know how long a command will take, so it starts a timer and
precmd cancels it. Nothing shows unless the timer outlives the command.

Commands Claude runs go here too, in their own color and their own slot,
through PreToolUse and PostToolUse hooks on Bash — the first shows the
command, the second clears it. They appear immediately rather than after a
delay, since a tool call is already known to be running.

The two slots are separate so Claude running a command does not push out one
of yours. Terminal windows still share the user slot, though: with a build
going in one window, a command finished in another clears the display.

This is why `last_command` only ever shows finished commands: whatever is
still running lives in `running_command` instead.

### Claude Sessions

The `claude` widget shows one icon per live Claude Code session, each in its
own color, and dims or brightens it with what the session is doing:

| State           | Look           | Meaning                                      |
| --------------- | -------------- | -------------------------------------------- |
| Idle            | Dimmed         | The turn ended. Nothing is pending.          |
| Answering       | Pulsing        | Claude is working.                           |
| Waiting for you | Bright, steady | Claude stopped mid-turn and needs an answer. |

Idle and waiting are both your turn; waiting means Claude is blocked on you,
which is what tells you where to look first when several sessions are open.

Waiting is set by a permission request or a prompt for input, and cleared when
the turn ends. Approving a permission does not clear it on its own, so a
session can read as waiting while Claude works through the rest of the turn.
Clearing it sooner would need a PostToolUse hook, which costs about 18ms on
every tool call — not worth it for a label that corrects itself moments later.

It is driven by Claude Code hooks. Link them in and register them:

```bash
ln -sf ~/.config/sketchybar/hooks/claude-sessions.py \
  ~/.claude/hooks/sketchybar-claude-sessions.py
ln -sf ~/.config/sketchybar/hooks/claude-command.sh \
  ~/.claude/hooks/sketchybar-claude-command.sh
```

Then in `~/.claude/settings.json`, add
`python3 ~/.claude/hooks/sketchybar-claude-sessions.py` to SessionStart,
SessionEnd, UserPromptSubmit, Stop and Notification, and
`sh ~/.claude/hooks/sketchybar-claude-command.sh` to PreToolUse with a `Bash`
matcher. Add them alongside whatever hooks are already registered — the arrays
take more than one entry.

Both hooks swallow every error and always exit 0, so a broken bar cannot
disturb a Claude session. Sessions killed without firing SessionEnd drop off
once their pid is gone.

### Layout

Widgets are grouped into left, center and right containers, each sharing a
rounded background. Standalone widgets — spaces and the Claude session icons —
get a background of their own instead, separated from the rest by a wider gap,
so each reads as its own area. The Claude one hides itself when no session is
running.

### Themes

Multiple themes are available:

**Dark Themes**:

- `onedark` (default) - One Dark color scheme
- `nord` - Nord color scheme
- `tokyonight` - Tokyo Night color scheme
- `githubdark` - GitHub Dark color scheme
- `gruvboxdark` - Gruvbox Dark color scheme
- `ayudark` - Ayu Dark color scheme

**Light Themes**:

- `onelight` - One Light color scheme
- `githublight` - GitHub Light color scheme
- `gruvboxlight` - Gruvbox Light color scheme
- `blossomlight` - Blossom Light color scheme
- `ayulight` - Ayu Light color scheme

Switch themes via the config menu or by setting:

```bash
export SBAR_THEME="nord"  # Choose any theme name
```

## Troubleshooting

### Icons not displaying

1. Check font installation:

   ```bash
   fc-list | grep -i "space mono"
   fc-list | grep -i "sketchybar-app-font"
   ```

2. Restart Sketchybar:
   ```bash
   brew services restart sketchybar
   ```

### Apps not showing in spaces

Verify yabai is installed and running:

```bash
brew services list | grep yabai
yabai -m query --spaces
```

### Weather not displaying

Check internet connection and curl:

```bash
curl -s "wttr.in/Seoul?format=j1"
```

### Permission errors

Grant execute permissions to scripts:

```bash
chmod +x ~/.config/sketchybar/sketchybarrc
chmod +x ~/.config/sketchybar/events/*.sh
chmod +x ~/.config/sketchybar/scripts/*.sh
```

## Credits

- [sketchybar](https://github.com/FelixKratz/SketchyBar) by FelixKratz
- [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) by kvndrsslr
- [Nerd Fonts](https://www.nerdfonts.com/)

## License

MIT
