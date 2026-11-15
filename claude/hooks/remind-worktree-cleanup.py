#!/usr/bin/env python3
"""Stop hook that sends Claude back to clean up git worktrees it created in
this session (recorded by ask-worktree-creation.py) but left behind.

Each recorded worktree is reminded about once, then dropped from the record:
if the user decided to keep it, later turns are not nagged again. Dropping
the record before blocking also guarantees the Stop hook can't loop.

Exit 2 blocks the stop and feeds stderr back to the model (Claude Code Stop
hook contract). Any unexpected error fails open (exit 0).
"""
import json
import os
import sys

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/worktrees")

GUIDANCE = (
    "このセッションで作成した worktree が残っています:\n{paths}\n"
    "不要なら `git worktree remove <path>` で削除し、不要になったブランチも整理してください。"
    "残す必要がある場合は、その旨をユーザーに確認してください。"
)


def main() -> int:
    try:
        data = json.load(sys.stdin)
        session_id = data.get("session_id")
        if not session_id:
            return 0
        state_file = os.path.join(STATE_DIR, f"{session_id}.json")
        if not os.path.exists(state_file):
            return 0
        with open(state_file) as f:
            recorded = json.load(f)
        os.remove(state_file)
        remaining = [p for p in recorded if os.path.isdir(p)]
    except Exception:
        return 0

    if not remaining:
        return 0
    print(GUIDANCE.format(paths="\n".join(f"- {p}" for p in remaining)), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
