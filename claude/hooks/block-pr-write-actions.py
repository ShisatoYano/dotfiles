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

Text that is never run (quoted strings, heredoc bodies written by cat/tee/git,
and the usual `$(cat <<'EOF' ... EOF)` commit-message form) is ignored when
looking for a gh invocation, so a commit message or grep pattern that merely
mentions these commands passes. When quoted text may itself be run (a shell,
ssh, eval, xargs, a -c/-e option, any other `$`/backtick expansion, ...) or the
command can't be parsed, the whole command is matched as before; a mention
next to such a form is therefore still blocked.

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
# Not split on newlines: a backslash-continued `gh api` would lose its -X/-f line and pass as a GET.
SEGMENT = re.compile(r"&&|\|\||;|\|")

# Forms that may run quoted text or a heredoc body.
EXEC_HINT = re.compile(
    r"\b(?:(?:ba|z|da|k|fi)?sh|ssh|eval|xargs|watch|parallel|awk|php|tmux)\b"
    r"|\s-[ce]\b"
    r"|\|\s*\w*(?:python|perl|ruby|node)"
    r"|[<>]\("
)
# `$(cat <<'EOF' ... EOF)`: the quoted delimiter keeps the body from being expanded or run.
INERT_SUBST = re.compile(
    r"\$\(\s*cat\s+<<-?[ \t]*(['\"])(\w+)\1[ \t]*\n"
    r"(?:(?![ \t]*\2[ \t]*\n)[^\n]*\n)*"
    r"[ \t]*\2\n\s*\)"
)
HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)(\w+)\1(?=[\s;|&)<>]|$)")
HEREDOC_SINK = re.compile(r"(?:^|[;&|(\n])\s*(?:cat|tee|git)\b[^\n;&|]*$")


def exec_view(command: str) -> str:
    """Return command with never-run text blanked (same length), or command
    itself when quoted text may be run or the command can't be parsed."""
    try:
        n = len(command)
        view = list(command)
        hint = list(command)  # command minus inert substitutions, for EXEC_HINT

        def blank(buf: list[str], start: int, end: int) -> None:
            end = min(end, n)
            buf[start:end] = " " * (end - start)

        i, in_dq, pending = 0, False, []
        while i < n:
            c = command[i]
            if c == "\\":
                if in_dq:
                    blank(view, i, i + 2)
                i += 2
            elif c in "$`":
                m = INERT_SUBST.match(command, i)
                if not m:
                    return command
                blank(view, i, m.end())
                blank(hint, i, m.end())
                i = m.end()
            elif c == '"':
                in_dq = not in_dq
                i += 1
            elif in_dq:
                view[i] = " "
                i += 1
            elif c == "'":
                j = command.find("'", i + 1)
                if j < 0:
                    return command
                blank(view, i + 1, j)
                i = j + 1
            elif command.startswith("<<<", i):
                i += 3
            elif command.startswith("<<", i):
                m = HEREDOC.match(command, i)
                if not m or not HEREDOC_SINK.search(command[:i]):
                    return command
                pending.append(m)
                i = m.end()
            elif c == "\n" and pending:
                for m in pending:
                    end = re.compile(
                        r"^[ \t]*%s[ \t]*$" % m.group(2), re.M
                    ).search(command, i + 1)
                    if not end:
                        return command
                    if not m.group(1) and re.search(r"[$`]", command[i : end.start()]):
                        return command  # unquoted delimiter: the body is expanded
                    blank(view, i, end.end())
                    i = end.end()
                pending = []
            else:
                i += 1
        if in_dq or pending or EXEC_HINT.search("".join(hint)):
            return command
        return "".join(view)
    except Exception:
        return command


def split_pairs(pattern: re.Pattern, view: str, command: str) -> list[tuple[str, str]]:
    """Split on operators found in view; return (view part, command part)."""
    pairs, start = [], 0
    for m in pattern.finditer(view):
        pairs.append((view[start : m.start()], command[start : m.start()]))
        start = m.end()
    pairs.append((view[start:], command[start:]))
    return pairs


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


def is_chained_allowed_post(view: str, command: str) -> bool:
    # Strip quoted text first so `--jq '.a | .b'` isn't mistaken for a pipe.
    if not CHAIN.search(QUOTED.sub("''", view.strip())):
        return False
    return any(
        GH_API.search(seen) and is_allowed_post(segment)
        for seen, segment in split_pairs(CHAIN, view, command)
    )


def find_pr_write_action(view: str, command: str) -> str | None:
    # Whether gh runs is judged on view; what it does is read from the original
    # text, because method, path and query are often quoted (-X "DELETE").
    for seen, segment in split_pairs(SEGMENT, view, command):
        segment = segment.strip()
        if not segment:
            continue
        if GH_PR_MERGE.search(seen) and not MATCH_HEAD.search(segment):
            return f"gh pr merge without --match-head-commit: {segment}"
        for pattern, label in PATTERNS:
            if pattern.search(seen):
                return f"{label}: {segment}"
        if GH_API.search(seen) and is_gh_api_write(segment):
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
        view = exec_view(command)
        reason = find_pr_write_action(view, command)
        chained = is_chained_allowed_post(view, command)
        merge = GH_PR_MERGE.search(view)
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
