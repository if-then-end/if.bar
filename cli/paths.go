package main

import (
	"os"
	"path/filepath"
)

type layout struct {
	config string
}

// configDir resolves where the bar's files live. The binary can sit anywhere,
// so unlike the shell scripts it cannot derive this from its own location.
func newLayout(override string) layout {
	if override != "" {
		return layout{config: override}
	}
	if env := os.Getenv("IF_BAR_CONFIG_DIR"); env != "" {
		return layout{config: env}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return layout{config: ".config/sketchybar"}
	}
	return layout{config: filepath.Join(home, ".config", "sketchybar")}
}

func (l layout) path(parts ...string) string {
	return filepath.Join(append([]string{l.config}, parts...)...)
}

func home(parts ...string) string {
	dir, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(parts...)
	}
	return filepath.Join(append([]string{dir}, parts...)...)
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func nonEmpty(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Size() > 0
}
