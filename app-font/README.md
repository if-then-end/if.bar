# Local app-font overrides

Files here are copied over the upstream clone by `scripts/update-app-font.sh`
right before the font is built, so an upstream refresh keeps them.

```
app-font/svgs/:name:.svg    the glyph  (filename carries the colons)
app-font/mappings/:name:    the apps that map to it, one quoted name per line
```

`svgtofont` names each glyph after its file. Overriding an existing glyph needs
only the SVG, since the mapping already exists upstream; a new glyph needs both
files. An SVG with no mapping is only an informational note to the upstream
validator, not an error.

Editing an SVG changes the font but not the map, so the updater keeps a digest
of these two directories in `~/.local/state/if.bar/app-font-overlay` and rebuilds
when it moves. Without it a changed glyph would be reported as up to date and the
old font left installed. The digest stays out of the map because the map is
committed and the overrides are not.

## Drawing pixel art

Cells are drawn as one rectangle each into a `viewBox="0 0 100 100"` path, so an
unfilled cell is simply absent and there is no winding to get wrong - eyes and
other holes cost nothing.

Terminal art copied out of a banner needs its cells drawn about 2.4x taller than
wide. A character cell is roughly that ratio, so square cells would squash the
shape, and a grid much wider than it is tall would fill only a fraction of the
glyph box. A wide, flat glyph still reads smaller than a squarer one at the same
point size - `IF_BAR_CLAUDE_ICON_SIZE` exists for exactly that.

Notes for an override that lives here belong here too, since the override itself
is not tracked.
