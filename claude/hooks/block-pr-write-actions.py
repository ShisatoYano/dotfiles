#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that blocks PR state-changing operations:
`gh pr merge`, `gh pr review` (any form), `gh pr comment`, plus their raw-API
equivalents (non-GET `gh api` to repos/*/pulls|issues, GraphQL mutations).

Exception: POSTs that `pr-workflow` sends itself are allowed — submitting a
review (approve/request-changes/comment) and replying to review comments.
`gh pr merge --match-head-commit <sha>` is not blocked but asks the user
(permissionDecision "ask", which prompts even in auto mode); without that flag
it is blocked so a push after the merge check can't slip into the merge.
Every other write (API merge, edit, close, dismiss, resolve thread, ...) stays
with the user; this hook makes that boundary a hard system-level guarantee
instead of relying solely on Skill prose.

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
    "マージは gh pr merge <n> --repo <owner/repo> <方式> --match-head-commit <マージ可否チェック時のhead> の形でのみ、ユーザー承認つきで許可されています。"
    "それ以外の操作は、判断材料を提示してユーザー自身に行ってもらってください。"
)

CHAINED_GUIDANCE = (
    "許可されたPR書き込み(gh api -X POST の reviews / replies / issues comments)が他のコマンドとつながっています。 "
    "settings.jsonの許可ルールはコマンド全体の形で照合されるため、つないだ形は一致せずauto modeの分類器に拒否されます。"
    "本文ファイルはWriteツールで作成し、gh api -X POST ... の1コマンドだけを単独で実行し直してください。"
)

MERGE_ASK ="PRのマージにはユーザーの承認が必要です。マージ可否チェックの結果を確認してから承認してください。 (matched: {reason})"

GH_PR_MERGE = re.compile(r"\bgh\s+pr\s+merge\b")
MATCH_HEAD = re.compile(r"\s--match-head-commit[\s=]+['\"]?[0-9a-f]{7,40}\b")

PATTERNS = [
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
QUOTED = re.compile(r"'[^']*'|\"[^\"]*\"")
CHAIN = re.compile(r"&&|\|\||[;|\n]")


def api_method(segment: str) -> str:
    m = METHOD.search(segment)
    return m.group(1).upper() if m else ("POST" if FIELD.search(segment) else "GET")


def is_allowed_post(segment: str) -> bool:
    return bool(
        GH_API.search(segment)
        and ALLOWED_POST.search(segment)
        and api_method(segment) == "POST"
    )


def is_gh_api_write(segment: str) -> bool:
    if not GH_API.search(segment):
        return False
    if GRAPHQL.search(segment):
        return bool(MUTATION.search(segment))
    if not PR_PATH.search(segment):
        return False
    if is_allowed_post(segment):
        return False
    return api_method(segment) != "GET"


def is_chained_allowed_post(command: str) -> bool:
    # Strip quoted text first so `--jq '.a | .b'` isn't mistaken for a pipe.
    if not CHAIN.search(QUOTED.sub("''", command.strip())):
        return False
    return any(is_allowed_post(s) for s in CHAIN.split(command))


def find_pr_write_action(command: str) -> str | None:
    for segment in re.split(r"&&|\|\||;|\|", command):
        segment = segment.strip()
        if not segment:
            continue
        if GH_PR_MERGE.search(segment) and not MATCH_HEAD.search(segment):
            return f"gh pr merge without --match-head-commit: {segment}"
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
        chained = is_chained_allowed_post(command)
        merge = GH_PR_MERGE.search(command)
    except Exception:
        return 0

    if chained and not reason:
        print(CHAINED_GUIDANCE, file=sys.stderr)
        return 2
    if reason:
        print(GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    if merge:
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "ask",
                        "permissionDecisionReason": MERGE_ASK.format(reason=command),
                    }
                },
                ensure_ascii=False,
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
