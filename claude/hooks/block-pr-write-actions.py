#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that blocks PR state-changing operations:
`gh pr merge`, `gh pr review` (any form), `gh pr comment`, plus their raw-API
equivalents (non-GET `gh api` to repos/*/pulls|issues, GraphQL mutations).

Exception: POSTs that `pr-workflow` sends itself are allowed — submitting a
review (approve/request-changes/comment) and replying to review comments.
Merging and every other write (edit, close, dismiss, resolve thread, ...)
stay with the user; this hook makes that boundary a hard system-level
guarantee instead of relying solely on Skill prose.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import re
import sys

GUIDANCE = (
    "PRの状態を変更する操作(gh pr merge/review/comment、およびgh api経由の同等操作)は禁止されています。 "
    "(matched: {reason})\n"
    "レビュー送信・返信は gh api -X POST の reviews / comments/<id>/replies / issues/<n>/comments のみ許可されています。"
    "マージ等それ以外の操作は、判断材料を提示してユーザー自身に行ってもらってください。"
)

PATTERNS = [
    (re.compile(r"\bgh\s+pr\s+merge\b"), "gh pr merge"),
    (re.compile(r"\bgh\s+pr\s+review\b"), "gh pr review"),
    (re.compile(r"\bgh\s+pr\s+comment\b"), "gh pr comment"),
]

GH_API = re.compile(r"\bgh\s+api\b")
GRAPHQL = re.compile(r"\bgh\s+api\s+graphql\b")
MUTATION = re.compile(r"\bmutation\b")
METHOD = re.compile(r"\s(?:-X|--method)[\s=]*['\"]?([A-Za-z]+)")
# gh api switches to POST implicitly when any field/input is given.
FIELD = re.compile(r"\s(?:-f|-F|--field|--raw-field|--input)[\s=]")
PR_PATH = re.compile(r"repos/[^/\s]+/[^/\s]+/(?:pulls|issues)\b")
ALLOWED_POST = re.compile(
    r"repos/[^/\s]+/[^/\s]+/"
    r"(?:pulls/\d+/reviews|pulls/\d+/comments/\d+/replies|issues/\d+/comments)"
    r"(?=[\s'\"]|$)"
)


def is_gh_api_write(segment: str) -> bool:
    if not GH_API.search(segment):
        return False
    if GRAPHQL.search(segment):
        return bool(MUTATION.search(segment))
    if not PR_PATH.search(segment):
        return False
    m = METHOD.search(segment)
    method = m.group(1).upper() if m else ("POST" if FIELD.search(segment) else "GET")
    if method == "POST" and ALLOWED_POST.search(segment):
        return False
    return method != "GET"


def find_pr_write_action(command: str) -> str | None:
    for segment in re.split(r"&&|\|\||;|\|", command):
        segment = segment.strip()
        if not segment:
            continue
        for pattern, label in PATTERNS:
            if pattern.search(segment):
                return f"{label}: {segment}"
        if is_gh_api_write(segment):
            return f"gh api (write): {segment}"
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
