#!/usr/bin/env python3
"""UserPromptSubmit hook (matcher: *) that reminds Claude to wrap up and hand
off once this session's context usage has crossed 50%.

No hook event receives context_window.used_percentage directly (only the
statusLine input does). statusline-command.sh detects the 50% crossing and
drops a marker file per session_id; this hook picks that marker up on the
next user prompt and reminds Claude here, since UserPromptSubmit is one of
the few events whose plain stdout is actually shown to Claude.

Fires at most once per session (tracked via a sibling `.notified` marker) so
it doesn't nag every turn after the first crossing.

Any unexpected error fails open (exit 0) so a bug here can't block prompts.
"""
import json
import os
import sys
import time

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/context-warnings")
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
        data = json.load(sys.stdin)
        session_id = data.get("session_id")
        if not session_id or not os.path.isdir(STATE_DIR):
            return 0

        prune_old_markers()

        crossed_path = os.path.join(STATE_DIR, session_id)
        notified_path = os.path.join(STATE_DIR, f"{session_id}.notified")
        if not os.path.exists(crossed_path) or os.path.exists(notified_path):
            return 0

        with open(notified_path, "w"):
            pass

        print(
            "コンテキスト使用率が50%を超えました。区切りの良いところで、"
            "`notion-task-workflow`のサブワークフロー1(進捗記録)の要領で"
            "ここまでの進捗をNotionタスクページと`daily-task-logs`の当日ファイル"
            "の両方に書き残し、ユーザーに新しいセッションでの続行を促してください。"
        )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
