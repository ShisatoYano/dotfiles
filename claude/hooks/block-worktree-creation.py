#!/usr/bin/env python3
"""PreToolUse hook (matchers: Bash, EnterWorktree) that blocks Claude from
autonomously creating a git worktree (`git worktree add` via Bash, or the
EnterWorktree tool).

Root cause this guards against: Claude was creating worktrees on its own
initiative during implementation work (e.g. via the EnterWorktree tool, or by
running `git worktree add` in Bash) without the user asking for isolation.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash/EnterWorktree call.
"""
import json
import re
import shlex
import sys

GUIDANCE_ENTER_WORKTREE = (
    "EnterWorktree の自律的な呼び出しは禁止されています。\n"
    "worktree での隔離作業が本当に必要な場合は、まずユーザー自身にその意図を確認してください。"
)

GUIDANCE_GIT_WORKTREE_ADD = (
    "git worktree add の自律的な実行は禁止されています。 (matched: {reason})\n"
    "worktree の作成が本当に必要な場合は、まずユーザー自身に意図を確認するか、"
    "ユーザー自身に `!git worktree add ...` を実行してもらってください。"
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


def is_git_worktree_add(tokens: list[str]) -> bool:
    if not tokens or tokens[0] != "git":
        return False
    saw_worktree = False
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("-"):
            if "=" in tok:
                i += 1
            elif tok in OPTS_WITH_ARG:
                i += 2
            else:
                i += 1
            continue
        if not saw_worktree:
            if tok != "worktree":
                return False
            saw_worktree = True
            i += 1
            continue
        return tok == "add"
    return False


def find_git_worktree_add(command: str) -> str | None:
    for segment in split_segments(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if is_git_worktree_add(tokens):
            return segment
    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
        tool_name = data.get("tool_name")

        if tool_name == "EnterWorktree":
            print(GUIDANCE_ENTER_WORKTREE, file=sys.stderr)
            return 2

        if tool_name != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        reason = find_git_worktree_add(command)
    except Exception:
        return 0

    if reason:
        print(GUIDANCE_GIT_WORKTREE_ADD.format(reason=reason), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
