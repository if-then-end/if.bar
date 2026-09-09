package main

import (
	"flag"
	"fmt"
	"os"
)

const usage = `ifbar - manage the if.bar sketchybar configuration

usage:
  ifbar doctor    report what is missing or broken

flags:
  --config DIR    where the configuration lives
                  (default $IF_BAR_CONFIG_DIR, else ~/.config/sketchybar)
`

func main() {
	configDir := flag.String("config", "", "where the configuration lives")
	flag.Usage = func() { fmt.Fprint(os.Stderr, usage) }
	flag.Parse()

	l := newLayout(*configDir)

	switch flag.Arg(0) {
	case "doctor":
		os.Exit(doctor(l))
	case "", "help", "-h", "--help":
		fmt.Print(usage)
	default:
		fmt.Fprintf(os.Stderr, "ifbar: unknown command %q\n\n%s", flag.Arg(0), usage)
		os.Exit(2)
	}
}
