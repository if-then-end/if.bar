#!/usr/bin/env python3
"""Report Claude session state to sketchybar.

Never fails: every error is swallowed and the exit code is always 0, so a
broken bar can never disturb a Claude session.
"""
import json
import os
import sys

STATE_DIR = os.path.join(os.path.expanduser("~"), ".local", "state", "if.bar")
STATE_PATH = os.path.join(STATE_DIR, "claude-sessions")
LOCK_PATH = STATE_PATH + ".lock"
PALETTE_SIZE = 8
SKETCHYBAR = "/opt/homebrew/bin/sketchybar"

IDLE, BUSY, WAITING = "idle", "busy", "waiting"

EVENT_STATE = {
    "SessionStart": IDLE,
    "UserPromptSubmit": BUSY,
    "Stop": IDLE,
    "PermissionRequest": WAITING,
}

WAITING_NOTIFICATIONS = {
    "permission_prompt",
    "elicitation_dialog",
    "elicitation_url_dialog",
    "agent_needs_input",
}

IDLE_NOTIFICATIONS = {
    "agent_completed",
    "elicitation_complete",
    "elicitation_response",
}


def notification_state(event):
    kind = event.get("notification_type") or ""
    if kind in WAITING_NOTIFICATIONS:
        return WAITING
    if kind in IDLE_NOTIFICATIONS:
        return IDLE
    return None


def read_event():
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def alive(pid):
    try:
        os.kill(pid, 0)
    except (OSError, ValueError, TypeError):
        return False
    return True


def load(path):
    entries = []
    try:
        with open(path) as handle:
            for line in handle:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3:
                    parts.append(IDLE)
                if len(parts) != 4:
                    continue
                session, pid, slot, state = parts
                try:
                    pid = int(pid)
                    slot = int(slot)
                except ValueError:
                    continue
                if state not in (IDLE, BUSY, WAITING):
                    state = IDLE
                entries.append([session, pid, slot, state])
    except FileNotFoundError:
        return []
    except Exception:
        return []
    return entries


def store(path, entries):
    tmp = path + ".tmp.%d" % os.getpid()
    try:
        with open(tmp, "w") as handle:
            for session, pid, slot, state in entries:
                handle.write("%s\t%d\t%d\t%s\n" % (session, pid, slot, state))
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except Exception:
            pass


def color_slot(session, taken):
    try:
        base = sum(ord(ch) for ch in session) % PALETTE_SIZE
    except Exception:
        base = 0
    for offset in range(PALETTE_SIZE):
        slot = (base + offset) % PALETTE_SIZE
        if slot not in taken:
            return slot
    return base


def notify():
    try:
        binary = SKETCHYBAR
        if not os.access(binary, os.X_OK):
            from shutil import which

            binary = which("sketchybar")
        if not binary:
            return
        pid = os.fork()
        if pid == 0:
            try:
                devnull = os.open(os.devnull, os.O_RDWR)
                os.dup2(devnull, 0)
                os.dup2(devnull, 1)
                os.dup2(devnull, 2)
                os.execv(binary, [binary, "--trigger", "claude_sessions"])
            except Exception:
                pass
            finally:
                os._exit(0)
    except Exception:
        pass


def main():
    event = read_event()
    name = event.get("hook_event_name") or ""
    session = event.get("session_id") or ""

    changed = False
    lock = None
    try:
        os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    except Exception:
        pass

    try:
        import fcntl

        lock = open(LOCK_PATH, "w")
        fcntl.flock(lock, fcntl.LOCK_EX)
    except Exception:
        lock = None

    try:
        loaded = load(STATE_PATH)
        original = [list(entry) for entry in loaded]
        entries = [entry for entry in loaded if alive(entry[1])]

        if session:
            if name == "SessionEnd":
                entries = [entry for entry in entries if entry[0] != session]
            else:
                if name == "Notification":
                    state = notification_state(event)
                else:
                    state = EVENT_STATE.get(name)
                if state is not None:
                    existing = next((e for e in entries if e[0] == session), None)
                    if existing is not None:
                        existing[3] = state
                    else:
                        parent = os.getppid()
                        if alive(parent):
                            taken = {entry[2] for entry in entries}
                            entries.append(
                                [session, parent, color_slot(session, taken), state]
                            )

        if entries != original:
            store(STATE_PATH, entries)
            changed = True
    except Exception:
        pass
    finally:
        if lock is not None:
            try:
                lock.close()
            except Exception:
                pass

    if changed:
        notify()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
