package main

import (
	"fmt"
	"os"
	"strings"
)

// A report collects results so the exit code can distinguish something broken
// from something merely worth mentioning.
type report struct {
	failures int
	warnings int
	color    bool
}

func newReport() *report {
	info, err := os.Stdout.Stat()
	tty := err == nil && info.Mode()&os.ModeCharDevice != 0
	return &report{color: tty}
}

const (
	green  = "\033[32m"
	yellow = "\033[33m"
	red    = "\033[31m"
	dim    = "\033[2m"
	off    = "\033[0m"
)

func (r *report) paint(code, text string) string {
	if !r.color {
		return text
	}
	return code + text + off
}

func (r *report) section(name string) {
	fmt.Printf("\n%s\n", r.paint(dim, name))
}

func (r *report) ok(format string, args ...any) {
	fmt.Printf("  %s    %s\n", r.paint(green, "ok"), fmt.Sprintf(format, args...))
}

func (r *report) warn(format string, args ...any) {
	r.warnings++
	fmt.Printf("  %s  %s\n", r.paint(yellow, "warn"), fmt.Sprintf(format, args...))
}

func (r *report) fail(format string, args ...any) {
	r.failures++
	fmt.Printf("  %s  %s\n", r.paint(red, "fail"), fmt.Sprintf(format, args...))
}

func (r *report) note(format string, args ...any) {
	fmt.Printf("        %s\n", r.paint(dim, fmt.Sprintf(format, args...)))
}

// summary returns the exit code: broken things fail the run, warnings do not.
func (r *report) summary() int {
	r.section("Summary")
	switch {
	case r.failures > 0:
		fmt.Printf("  %s, %s\n",
			r.paint(red, plural(r.failures, "broken thing", "broken things")),
			plural(r.warnings, "warning", "warnings"))
		return 1
	case r.warnings > 0:
		fmt.Printf("  %s, nothing broken\n", r.paint(yellow, plural(r.warnings, "warning", "warnings")))
	default:
		fmt.Printf("  %s\n", r.paint(green, "all clear"))
	}
	return 0
}

func plural(n int, one, many string) string {
	if n == 1 {
		return fmt.Sprintf("%d %s", n, one)
	}
	return fmt.Sprintf("%d %s", n, many)
}

func indent(lines []string) string {
	return strings.Join(lines, " ")
}
