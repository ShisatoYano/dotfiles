#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that hard-blocks `git push`.

Root cause this guards against: unlike `git checkout`/`gh pr merge` etc.
(regex-segment-split, see block-branch-checkout.py / block-pr-write-actions.py),
`git push` detection needs to be robust against quoted/heredoc text that merely
*contains* the words "git push" (e.g. inside a commit message body) without
being an actual invocation — a real false positive was hit with the regex
approach while committing this repo's own PR-write hook. This hook instead
splits on shell operators while protecting quoted/heredoc spans, then
tokenizes each segment with shlex and inspects the token stream directly
(skipping git global options that take a separate argument) to decide whether
`push` is actually the subcommand being invoked.

A push is allowed only while a toggle file exists at
~/.local/state/claude-git-push/allowed (flipped by
scripts/claude-git-push-ctl.sh) — everything else is blocked by default.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import os
import re
import shlex
import sys

STATE_FILE = os.path.expanduser("~/.local/state/claude-git-push/allowed")

GUIDANCE = (
    "git push は既定でブロックされています。 (matched: {reason})\n"
    "一時的に許可する場合は、ユーザー自身に "
    "scripts/claude-git-push-ctl.sh on を実行してもらってください。"
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


def is_git_push(tokens: list[str]) -> bool:
    if not tokens or tokens[0] != "git":
        return False
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if not tok.startswith("-"):
            return tok == "push"
        if "=" in tok:
            i += 1
        elif tok in OPTS_WITH_ARG:
            i += 2
        else:
            i += 1
    return False


def find_git_push(command: str) -> str | None:
    for segment in split_segments(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if is_git_push(tokens):
            return segment
    return None


def main() -> int:
    try:
        if os.path.exists(STATE_FILE):
            return 0
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        reason = find_git_push(command)
    except Exception:
        return 0

    if reason:
        print(GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
