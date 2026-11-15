#!/usr/bin/env python3
"""PreToolUse hook (matchers: Bash, EnterWorktree) that asks the user for
approval before Claude creates a git worktree (`git worktree add` via Bash, or
the EnterWorktree tool).

Root cause this guards against: Claude was creating worktrees on its own
initiative during implementation work without the user asking for isolation,
and leaving them behind afterwards.

Emits permissionDecision "ask" on stdout (Claude Code PreToolUse hook
contract), so the permission prompt appears even in auto mode. Paths passed to
`git worktree add` are recorded per session so remind-worktree-cleanup.py
(Stop hook) can push Claude to remove them before ending its turn. Any
unexpected error here fails open (exit 0) so a bug in this script can't break
every Bash/EnterWorktree call.
"""
import json
import os
import re
import shlex
import sys

STATE_DIR = os.path.expanduser("~/.local/state/claude-code/worktrees")

GUIDANCE_ENTER_WORKTREE = (
    "worktree の作成(EnterWorktree)にはユーザーの承認が必要です。\n"
    "作業が終わったら ExitWorktree(action: remove)で後片付けしてください。"
)

GUIDANCE_GIT_WORKTREE_ADD = (
    "worktree の作成(git worktree add)にはユーザーの承認が必要です。 (matched: {reason})\n"
    "作業が終わったら `git worktree remove <path>` で削除してください。"
    "残す必要がある場合は、その旨をユーザーに確認してください。"
)

# git global options that consume the following token as their argument
OPTS_WITH_ARG = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--exec-path",
    "--super-prefix",
    "--config-env",
}

# `git worktree add` options that consume the following token as their argument
ADD_OPTS_WITH_ARG = {"-b", "-B", "--reason"}

# Matches quoted spans (to protect them) or shell operators (to split on).
# Only the operator alternative is captured in group 1.
_TOKEN_PAT = re.compile(
    r'"(?:[^"\\]|\\.)*"'
    r"|'(?:[^'\\]|\\.)*'"
    r"|(&&|\|\||;|\|(?!\|)|\n)"
)


def split_segments(command: str) -> list[str]:
    segments = []
    start = 0
    for m in _TOKEN_PAT.finditer(command):
        if m.group(1) is None:
            continue  # quoted span: protect, don't split inside it
        segments.append(command[start : m.start()])
        start = m.end()
    segments.append(command[start:])
    return segments


def worktree_add_path(tokens: list[str], cwd: str) -> str | None:
    """Return the absolute target path if tokens are `git ... worktree add`,
    "" if it is one but the path can't be determined, else None."""
    if not tokens or tokens[0] != "git":
        return None
    base = cwd
    i = 1
    while i < len(tokens) and tokens[i].startswith("-"):
        tok = tokens[i]
        if tok == "-C" and i + 1 < len(tokens):
            base = os.path.join(base, os.path.expanduser(tokens[i + 1]))
        i += 2 if ("=" not in tok and tok in OPTS_WITH_ARG) else 1
    if tokens[i : i + 2] != ["worktree", "add"]:
        return None
    i += 2
    while i < len(tokens):
        tok = tokens[i]
        if tok == "--":
            i += 1
            break
        if not tok.startswith("-"):
            break
        i += 2 if ("=" not in tok and tok in ADD_OPTS_WITH_ARG) else 1
    if i >= len(tokens):
        return ""
    return os.path.normpath(os.path.join(base, os.path.expanduser(tokens[i])))


def find_worktree_adds(command: str, cwd: str) -> list[tuple[str, str]]:
    """Return (segment, absolute path or "") for each `git worktree add`."""
    found = []
    for segment in split_segments(command):
        segment = segment.strip().lstrip("(").rstrip(")").strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        # Follow plain `cd <dir>` so relative paths resolve like the shell would.
        if len(tokens) == 2 and tokens[0] == "cd":
            cwd = os.path.join(cwd, os.path.expanduser(tokens[1]))
            continue
        path = worktree_add_path(tokens, cwd)
        if path is not None:
            found.append((segment, path))
    return found


def record_paths(session_id: str, paths: list[str]) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    state_file = os.path.join(STATE_DIR, f"{session_id}.json")
    try:
        with open(state_file) as f:
            recorded = json.load(f)
    except (OSError, ValueError):
        recorded = []
    for p in paths:
        if p not in recorded:
            recorded.append(p)
    with open(state_file, "w") as f:
        json.dump(recorded, f, ensure_ascii=False)


def ask(reason: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": reason,
                }
            },
            ensure_ascii=False,
        )
    )


def main() -> int:
    try:
        data = json.load(sys.stdin)
        tool_name = data.get("tool_name")

        if tool_name == "EnterWorktree":
            ask(GUIDANCE_ENTER_WORKTREE)
            return 0

        if tool_name != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        found = find_worktree_adds(command, data.get("cwd") or os.getcwd())
        if not found:
            return 0
    except Exception:
        return 0

    ask(GUIDANCE_GIT_WORKTREE_ADD.format(reason=found[0][0]))
    try:
        # Recorded before approval: a denied call never creates the directory,
        # so the Stop hook's existence check filters it out.
        session_id = data.get("session_id")
        paths = [p for _, p in found if p]
        if session_id and paths:
            record_paths(session_id, paths)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
