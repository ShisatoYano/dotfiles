#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that asks the user for approval before
commands creating/switching the current git branch (git checkout <ref>,
git checkout -b, git switch, gh pr checkout).

Root cause this guards against: a Claude-driven Bash call (main agent or a
skill's subagent) checked out a PR under a local branch name and never
switched back, leaving the user's working tree on an unexpected branch with
no notice. Requiring approval per call keeps the user aware of every switch.

Emits permissionDecision "ask" on stdout (Claude Code PreToolUse hook
contract), so the permission prompt appears even in auto mode. Any unexpected
error here fails open (exit 0) so a bug in this script can't break every Bash
call.
"""
import json
import re
import shlex
import sys

GUIDANCE = (
    "ブランチの作成・切替(git checkout/switch, gh pr checkout)にはユーザーの承認が必要です。 "
    "(matched: {reason})\n"
    "既存ブランチへ切り替えた場合は、作業後に元のブランチへ戻してください。"
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


def git_subcommand(tokens: list[str]) -> tuple[str, list[str]] | None:
    if not tokens or tokens[0] != "git":
        return None
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if not tok.startswith("-"):
            return tok, tokens[i + 1 :]
        if "=" not in tok and tok in OPTS_WITH_ARG:
            i += 2
        else:
            i += 1
    return None


def switch_reason(tokens: list[str]) -> str | None:
    if tokens[:3] == ["gh", "pr", "checkout"]:
        return "gh pr checkout"

    parsed = git_subcommand(tokens)
    if not parsed:
        return None
    sub, args = parsed
    if sub == "switch":
        return "git switch"
    if sub != "checkout" or "--" in args:
        return None  # file-restore form: blocked separately by block-discard-changes.py

    flags = [t for t in args if t.startswith("-")]
    nonflags = [t for t in args if not t.startswith("-")]
    if "-b" in flags or "-B" in flags:
        return "git checkout -b/-B (creates+switches branch)"
    if not nonflags:
        return None  # bare `git checkout`, no-op
    if "/" in nonflags[0] or "." in nonflags[0]:
        return None  # looks like a pathspec, not a ref
    return "git checkout <ref>"


def find_branch_switch(command: str) -> str | None:
    for segment in split_segments(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        reason = switch_reason(tokens)
        if reason:
            return f"{reason}: {segment}"

    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        reason = find_branch_switch(command)
    except Exception:
        return 0

    if reason:
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "ask",
                        "permissionDecisionReason": GUIDANCE.format(reason=reason),
                    }
                },
                ensure_ascii=False,
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
