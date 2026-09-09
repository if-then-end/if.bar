package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

func doctor(l layout) int {
	r := newReport()

	fmt.Println("if.bar doctor")
	r.note("%s", l.config)

	checkDependencies(r)
	checkFonts(r, l)
	checkConfiguration(r, l)
	checkRuntime(r)
	checkOptional(r)

	return r.summary()
}

func checkDependencies(r *report) {
	r.section("Dependencies")

	if path, ok := look("sketchybar"); ok {
		version, _ := output(path, "--version")
		r.ok("sketchybar %s", firstLine(version))
	} else {
		r.fail("sketchybar not installed (brew install FelixKratz/formulae/sketchybar)")
	}

	if _, ok := look("lua"); ok {
		r.ok("lua")
	} else {
		r.fail("lua not installed (brew install lua)")
	}

	if exists(home(".local", "share", "sketchybar_lua", "sketchybar.so")) {
		r.ok("SbarLua")
	} else {
		r.fail("SbarLua missing - the bar cannot start without it")
		r.note("github.com/FelixKratz/SbarLua")
	}

	if _, ok := look("jq"); ok {
		r.ok("jq")
	} else {
		r.warn("jq missing - the space and weather widgets need it")
	}

	if _, ok := look("pnpm"); ok {
		r.ok("pnpm")
	} else {
		r.warn("pnpm missing - only the font refresh needs it")
	}

	checkNode(r)
}

// The font build runs under pnpm, which refuses to start on older Node, and an
// outdated /usr/local/bin/node often shadows a current one.
func checkNode(r *report) {
	if path, ok := look("node"); ok && nodeUsable(path) {
		version, _ := output(path, "-v")
		r.ok("node %s", firstLine(version))
		return
	}

	candidates := []string{"/opt/homebrew/bin/node", "/usr/local/opt/node/bin/node"}
	if brew, ok := look("brew"); ok {
		if prefix, err := output(brew, "--prefix", "node"); err == nil {
			candidates = append([]string{filepath.Join(firstLine(prefix), "bin", "node")}, candidates...)
		}
	}
	for _, candidate := range candidates {
		if nodeUsable(candidate) {
			version, _ := output(candidate, "-v")
			r.ok("node %s at %s", firstLine(version), filepath.Dir(candidate))
			r.note("not first on PATH; the font refresh looks past the one that is")
			return
		}
	}
	r.warn("no node >= 22.13 - only the font refresh needs it")
}

func nodeUsable(path string) bool {
	if path == "" {
		return false
	}
	if info, err := os.Stat(path); err != nil || info.IsDir() {
		return false
	}
	version, err := output(path, "-v")
	if err != nil {
		return false
	}
	parts := strings.SplitN(strings.TrimPrefix(firstLine(version), "v"), ".", 3)
	if len(parts) < 2 {
		return false
	}
	major, err := strconv.Atoi(parts[0])
	if err != nil {
		return false
	}
	minor, err := strconv.Atoi(parts[1])
	if err != nil {
		return false
	}
	return major > 22 || (major == 22 && minor >= 13)
}

func checkFonts(r *report, l layout) {
	r.section("Fonts")

	appFont := home("Library", "Fonts", "sketchybar-app-font.ttf")
	if nonEmpty(appFont) {
		r.ok("sketchybar-app-font")
	} else {
		r.fail("sketchybar-app-font missing - app icons render as text like :ghostty:")
		r.note("refresh it with: %s", l.path("scripts", "update-app-font.sh"))
	}

	if nerdFontInstalled() {
		r.ok("a Nerd Font is installed")
	} else {
		r.warn("no Nerd Font found - widget icons render as boxes")
		r.note("brew install --cask font-space-mono-nerd-font")
	}

	checkGlyphs(r, l, appFont)
}

func nerdFontInstalled() bool {
	for _, dir := range []string{home("Library", "Fonts"), "/Library/Fonts"} {
		matches, _ := filepath.Glob(filepath.Join(dir, "*NerdFont*"))
		if len(matches) > 0 {
			return true
		}
	}
	return false
}

var glyphReference = regexp.MustCompile(`"(:[a-z0-9_]+:)"`)

// The map holds ligature names the font turns into glyphs, so a name the font
// does not carry reaches the bar as literal text. They only line up when both
// came from the same build.
func checkGlyphs(r *report, l layout, appFont string) {
	mapPath := l.path("lua", "icons", "apps.lua")
	if !nonEmpty(appFont) || !exists(mapPath) {
		return
	}

	names, err := glyphNames(appFont)
	if err != nil {
		r.warn("could not read the font's glyph names: %v", err)
		return
	}
	if names == nil {
		r.note("the font carries no glyph names, nothing to compare the map against")
		return
	}

	source, err := os.ReadFile(mapPath)
	if err != nil {
		r.warn("could not read %s: %v", mapPath, err)
		return
	}

	seen := map[string]bool{}
	var missing []string
	for _, match := range glyphReference.FindAllStringSubmatch(string(source), -1) {
		name := match[1]
		if seen[name] || names[name] {
			continue
		}
		seen[name] = true
		missing = append(missing, name)
	}

	if len(missing) == 0 {
		r.ok("icon map matches the installed font")
		return
	}
	sort.Strings(missing)
	shown := missing
	if len(shown) > 6 {
		shown = shown[:6]
	}
	r.fail("icon map references %s the font lacks: %s",
		plural(len(missing), "glyph", "glyphs"), strings.Join(shown, " "))
	r.note("rebuild both together: %s", l.path("scripts", "update-app-font.sh"))
}

var legacyPrefix = regexp.MustCompile(`(?m)^\s*(export\s+)?SBAR_`)

func checkConfiguration(r *report, l layout) {
	r.section("Configuration")

	switch {
	case exists(l.path("ifbarrc")):
		r.ok("reading ifbarrc")
	case exists(l.path("user.sketchybarrc")):
		r.ok("reading user.sketchybarrc")
		r.note("the current name is ifbarrc; this one is read only when it is absent")
		if body, err := os.ReadFile(l.path("user.sketchybarrc")); err == nil && legacyPrefix.Match(body) {
			r.warn("settings still use the SBAR_ prefix - mapped on read, but IF_BAR_ is current")
		}
	default:
		r.ok("no config file - running on the defaults in lua/config.lua")
		r.note("cp ifbarrc.example ifbarrc to change anything")
	}

	if broken := unparsableLua(l); len(broken) == 0 {
		r.ok("every Lua file parses")
	} else {
		r.fail("does not parse: %s", indent(broken))
	}

	stateDir := home(".local", "state", "if.bar")
	if info, err := os.Stat(stateDir); err == nil {
		if mode := info.Mode().Perm(); mode == 0o700 {
			r.ok("state directory is owner-only")
		} else {
			r.warn("state directory is %o, expected 700 - %s", mode, stateDir)
		}
	}
}

func unparsableLua(l layout) []string {
	checker, args, ok := luaChecker()
	if !ok {
		return nil
	}

	var files []string
	files = append(files, l.path("sketchybarrc"))
	for _, pattern := range [][]string{{"lua", "*.lua"}, {"lua", "*", "*.lua"}} {
		matches, _ := filepath.Glob(l.path(pattern...))
		files = append(files, matches...)
	}

	var broken []string
	for _, file := range files {
		if !exists(file) {
			continue
		}
		if err := exec.Command(checker, append(args, file)...).Run(); err != nil {
			relative, relErr := filepath.Rel(l.config, file)
			if relErr != nil {
				relative = file
			}
			broken = append(broken, relative)
		}
	}
	return broken
}

func luaChecker() (string, []string, bool) {
	if path, ok := look("luac"); ok {
		return path, []string{"-p"}, true
	}
	if path, ok := look("lua"); ok {
		return path, []string{"-e", "assert(loadfile(arg[1]))", "--"}, true
	}
	return "", nil, false
}

func checkRuntime(r *report) {
	r.section("Runtime")

	daemon, ok := pidOf("sketchybar")
	if !ok {
		r.fail("sketchybar not running (brew services start sketchybar)")
		return
	}
	r.ok("sketchybar running (pid %d)", daemon)

	switch configs := configProcesses(daemon); configs {
	case 1:
		r.ok("one config process")
	case 0:
		r.fail("no config process - the bar is empty until sketchybar --reload")
	default:
		r.warn("%d config processes - each runs its own event loop", configs)
	}

	if items, err := barItems(); err != nil {
		r.warn("could not query the bar: %v", err)
	} else if items > 0 {
		r.ok("%s on the bar", plural(items, "item", "items"))
	} else {
		r.fail("no items on the bar - try sketchybar --reload")
	}
}

func barItems() (int, error) {
	path, ok := look("sketchybar")
	if !ok {
		return 0, fmt.Errorf("sketchybar not installed")
	}
	raw, err := output(path, "--query", "bar")
	if err != nil {
		return 0, err
	}
	var bar struct {
		Items []string `json:"items"`
	}
	if err := json.Unmarshal([]byte(raw), &bar); err != nil {
		return 0, err
	}
	return len(bar.Items), nil
}

func checkOptional(r *report) {
	r.section("Optional")

	path, ok := look("yabai")
	if !ok {
		r.note("yabai not installed - only the space widget uses it")
		return
	}
	if _, running := pidOf("yabai"); !running {
		r.warn("yabai installed but not running - the space widget falls back to one space")
		return
	}
	if spaces, err := output(path, "-m", "query", "--spaces"); err == nil && strings.Contains(spaces, `"index"`) {
		r.ok("yabai answers space queries")
		return
	}
	r.warn("yabai runs but --spaces returns nothing - try yabai --restart-service")
	r.note("the space widget builds its items from that query at load")
}
