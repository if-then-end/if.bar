# ifbar

A CLI for the parts of this repo that were shell scripts. Only `doctor` has
moved so far, and it is the only copy - the shell version is gone, so there is
one place to change a check. That costs a Go toolchain to build it, until there
is a released binary.

```bash
cd cli && go build -o ../bin/ifbar .
../bin/ifbar doctor
```

`bin/` is ignored, so the binary never lands in a commit.

## Why it is here rather than in its own repo

The repo root is the sketchybar config directory, so everything here is cloned
into `~/.config/sketchybar`. Go sources in a subdirectory are inert at runtime -
the bar reads `sketchybarrc` and `lua/`, nothing else.

Keeping it in the same repo also keeps it in step with what it inspects. The
glyph check compares `lua/icons/apps.lua` against the installed font, and the
config check reads `ifbarrc`; a separate repo would have to track which version
of this one it was written against.

## Finding the configuration

The binary can sit anywhere, so unlike the scripts it cannot derive the config
directory from its own path. In order: `--config`, `$IF_BAR_CONFIG_DIR`,
`~/.config/sketchybar`. Passing `--config` is also how to inspect a checkout
that is not the live one.

## Still to move

`update-app-font.sh` and its awk converter are the next worthwhile ones: both
carry an embedded Python block for reading the font, which `ttf.go` already
replaces. `update.sh` is thin enough that moving it buys little.

`install.sh` stays a script whatever happens - it runs before there is a binary
to run. `hooks/zsh-integration.zsh` stays too, because it is sourced into the
shell rather than executed.
