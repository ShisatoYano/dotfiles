#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that blocks PR state-changing operations:
`gh pr merge`, `gh pr review` (any form), `gh pr comment`.

Root cause this guards against: `pr-workflow` only drafts review text and
merge-readiness assessments — the user always performs the actual GitHub
action themselves. This hook makes that boundary a hard system-level
guarantee instead of relying solely on Skill prose.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import re
import sys

GUIDANCE = (
    "PRの状態を変更する操作(gh pr merge/review/comment)は禁止されています。 "
    "(matched: {reason})\n"
    "下書き・判断材料を提示するところまでで、実際の実行はユーザー自身に行ってもらってください。"
)

PATTERNS = [
    (re.compile(r"\bgh\s+pr\s+merge\b"), "gh pr merge"),
    (re.compile(r"\bgh\s+pr\s+review\b"), "gh pr review"),
    (re.compile(r"\bgh\s+pr\s+comment\b"), "gh pr comment"),
]


def find_pr_write_action(command: str) -> str | None:
    for segment in re.split(r"&&|\|\||;|\|", command):
        segment = segment.strip()
        if not segment:
            continue
        for pattern, label in PATTERNS:
            if pattern.search(segment):
                return f"{label}: {segment}"
    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        reason = find_pr_write_action(command)
    except Exception:
        return 0

    if reason:
        print(GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
