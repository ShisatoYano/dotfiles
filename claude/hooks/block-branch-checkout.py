#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that blocks commands switching the current
git branch (git checkout <ref>, git checkout -b, git switch, gh pr checkout).

Root cause this guards against: a Claude-driven Bash call (main agent or a
skill's subagent) checked out a PR under a local branch name and never
switched back, leaving the user's working tree on an unexpected branch with
no notice. Exploration of another branch's contents should go through
`git worktree add <path> <branch>` instead, which never touches the current
working tree's branch.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import re
import sys

GUIDANCE = (
    "ブランチの切替(git checkout/switch, gh pr checkout)は禁止されています。 "
    "(matched: {reason})\n"
    "作業ツリーのブランチを変えずに調べたい場合は "
    "git worktree add <path> <branch> で別ディレクトリにチェックアウトしてください。\n"
    "ユーザー自身が現在の作業ツリーのブランチを切り替えることを明示的に依頼した場合は、"
    "その旨を伝えて一時的に `!git checkout ...` をユーザー自身に実行してもらってください。"
)


def find_branch_switch(command: str) -> str | None:
    for segment in re.split(r"&&|\|\||;|\|", command):
        segment = segment.strip()
        if not segment:
            continue

        if re.search(r"\bgh\s+pr\s+checkout\b", segment):
            return f"gh pr checkout: {segment}"

        if re.search(r"\bgit\s+switch\b", segment):
            return f"git switch: {segment}"

        m = re.search(r"\bgit\s+checkout\b(.*)", segment)
        if not m:
            continue
        rest = m.group(1)
        tokens = rest.split()
        if "--" in tokens:
            continue  # file-restore form: `git checkout -- <path>` / `<ref> -- <path>`

        flags = [t for t in tokens if t.startswith("-")]
        nonflags = [t for t in tokens if not t.startswith("-")]
        if "-b" in flags or "-B" in flags:
            return f"git checkout -b/-B (creates+switches branch): {segment}"
        if not nonflags:
            continue  # bare `git checkout`, no-op

        target = nonflags[0]
        if "/" in target or "." in target:
            continue  # looks like a pathspec, not a ref
        return f"git checkout <ref>: {segment}"

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
        print(GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
