#!/usr/bin/env python3
"""PreCompact hook (matcher: *) that snapshots uncommitted git changes to disk.

Root cause this guards against: /compact summarizes away the reasoning behind
in-progress edits (e.g. a debug print added to confirm a bug hypothesis, or a
temporary test tweak), leaving no record of *why* the working tree looks the
way it does after compaction. PreCompact hook stdout is not injected into the
transcript (only parsed as JSON / logged to debug), so the only way to
preserve this is to write it to a file that a later hook or Claude itself can
read back.

Only runs when the session cwd is inside a git work tree with actual
uncommitted changes (staged, unstaged, or untracked); a clean tree writes
nothing. Snapshots are named `<session_id>__<epoch>.diff` under
~/.local/state/claude-code/pre-compact-diffs/ so the paired SessionStart
(matcher: compact) hook can find the latest one for this session. Snapshots
older than 30 days are pruned on each run to bound disk usage.

Any unexpected error fails open (exit 0) so a bug here can't block
compaction.
"""
import json
import os
import subprocess
import sys
import time

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/pre-compact-diffs")
RETENTION_SECONDS = 30 * 24 * 60 * 60


def run(cwd: str, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", cwd, *args],
        capture_output=True,
        text=True,
        timeout=10,
    )
    return result.stdout if result.returncode == 0 else ""


def prune_old_snapshots() -> None:
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
        cwd = data.get("cwd") or os.getcwd()
        if not session_id or not cwd:
            return 0

        inside = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if inside.returncode != 0 or inside.stdout.strip() != "true":
            return 0

        status = run(cwd, "status", "--short")
        if not status.strip():
            return 0  # clean tree, nothing worth preserving

        diff = run(cwd, "diff")
        diff_staged = run(cwd, "diff", "--staged")
        repo_name = os.path.basename(os.path.abspath(cwd))

        os.makedirs(STATE_DIR, exist_ok=True)
        prune_old_snapshots()

        timestamp = int(time.time())
        snapshot_path = os.path.join(
            STATE_DIR, f"{session_id}__{timestamp}.diff"
        )
        with open(snapshot_path, "w") as f:
            f.write(f"# repo: {repo_name}\n# cwd: {cwd}\n\n")
            f.write("## git status --short\n")
            f.write(status)
            f.write("\n## git diff --staged\n")
            f.write(diff_staged)
            f.write("\n## git diff\n")
            f.write(diff)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
