#!/usr/bin/env python3
"""SessionStart hook (matcher: compact) that re-surfaces the diff snapshot
saved by save-diff-before-compact.py right after /compact runs.

PreCompact hook stdout is never added to the transcript, but a SessionStart
(matcher: compact) hook's stdout IS injected into Claude's context as a
system reminder. Pairing the two lets Claude know where to grep for the
pre-compaction diff if the summary dropped details about why the working
tree looks the way it does (e.g. a debug print added mid-investigation).

Silent (no output) when no snapshot exists for this session, to avoid a
noisy reminder on every compaction of a clean tree.

Any unexpected error fails open (exit 0).
"""
import json
import os
import sys

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/pre-compact-diffs")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        session_id = data.get("session_id")
        if not session_id or not os.path.isdir(STATE_DIR):
            return 0

        prefix = f"{session_id}__"
        candidates = [
            name for name in os.listdir(STATE_DIR) if name.startswith(prefix)
        ]
        if not candidates:
            return 0

        latest = max(
            candidates,
            key=lambda name: os.path.getmtime(os.path.join(STATE_DIR, name)),
        )
        latest_path = os.path.join(STATE_DIR, latest)
        print(
            "直前の/compact前の未コミット差分をスナップショット保存済みです: "
            f"{latest_path}\n"
            "圧縮で再現手順・変更理由などの詳細が失われていそうな場合は、"
            "このファイルをReadして参照してください。"
        )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
