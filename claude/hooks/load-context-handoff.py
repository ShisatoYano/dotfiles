#!/usr/bin/env python3
"""SessionStart hook (matcher: startup) that surfaces today's daily-task-logs
entry once, so a fresh session picked up after a context-threshold handoff
(see warn-context-threshold.py) can find where the previous session left off.

Shown at most once per day (tracked via a `<date>.shown` marker), regardless
of which repo/cwd the new session starts in — matching cwd against the
handoff would need per-task bookkeeping this deliberately skips in favor of
staying simple; a stale reminder on an unrelated session is low-cost.

Silent when today's file doesn't exist or was already surfaced today.
Any unexpected error fails open (exit 0).
"""
import json
import os
import sys
import time

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/context-handoffs")
NB_DIR = os.environ.get("NB_DIR") or os.path.expanduser("~/.nb")
RETENTION_SECONDS = 30 * 24 * 60 * 60


def prune_old_markers() -> None:
    now = time.time()
    for name in os.listdir(STATE_DIR):
        path = os.path.join(STATE_DIR, name)
        try:
            if now - os.path.getmtime(path) > RETENTION_SECONDS:
                os.remove(path)
        except OSError:
            pass


def main() -> int:
    try:
        json.load(sys.stdin)  # session_id/cwd not needed; read to drain stdin cleanly

        today = time.strftime("%Y-%m-%d")
        log_path = os.path.join(NB_DIR, "daily-task-logs", "daily", f"{today}.md")
        if not os.path.isfile(log_path):
            return 0

        os.makedirs(STATE_DIR, exist_ok=True)
        prune_old_markers()

        shown_path = os.path.join(STATE_DIR, f"{today}.shown")
        if os.path.exists(shown_path):
            return 0

        with open(shown_path, "w"):
            pass

        print(
            f"本日({today})の daily-task-logs に途中経過/まとめが記録されています: "
            f"{log_path}\n"
            "コンテキスト区切りによる引き継ぎがあれば、このファイルをReadして"
            "続きを確認してください。"
        )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
