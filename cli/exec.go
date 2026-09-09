package main

import (
	"os/exec"
	"strconv"
	"strings"
)

func look(name string) (string, bool) {
	path, err := exec.LookPath(name)
	return path, err == nil
}

// output runs a command and returns its stdout trimmed. Callers that only want
// to know whether it worked can ignore the string.
func output(name string, args ...string) (string, error) {
	raw, err := exec.Command(name, args...).Output()
	return strings.TrimSpace(string(raw)), err
}

func firstLine(text string) string {
	if index := strings.IndexByte(text, '\n'); index >= 0 {
		return text[:index]
	}
	return text
}

func pidOf(name string) (int, bool) {
	// -x so "sketchybar" does not also match the config process, whose command
	// line is the lua interpreter running sketchybarrc.
	raw, err := output("pgrep", "-x", name)
	if err != nil {
		return 0, false
	}
	pid, err := strconv.Atoi(firstLine(raw))
	if err != nil {
		return 0, false
	}
	return pid, true
}

// configProcesses counts the Lua processes sketchybar itself started. More than
// one means several event loops are driving the same bar; none means the bar
// keeps whatever items it had and stops updating.
func configProcesses(daemon int) int {
	raw, err := output("ps", "-eo", "pid,ppid,command")
	if err != nil {
		return 0
	}
	parent := strconv.Itoa(daemon)
	count := 0
	for _, line := range strings.Split(raw, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 3 || fields[1] != parent {
			continue
		}
		command := strings.Join(fields[2:], " ")
		if strings.Contains(command, "lua") && strings.Contains(command, "sketchybarrc") {
			count++
		}
	}
	return count
}
