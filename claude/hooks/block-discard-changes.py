#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that blocks git commands discarding
working-tree changes (git checkout -- <path>, git restore, git reset --hard,
git stash, git clean -f).

Root cause this guards against: when Claude saw diffs it hadn't made itself,
it treated them as unexpected tampering and reverted them — wiping out edits
the user had made by hand. Uncommitted changes can't be recovered once
discarded, so these commands are left to the user to run themselves.

Segment splitting protects quoted spans (same approach as block-git-push.py), so text
that merely mentions e.g. "git stash" inside a commit message isn't blocked.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import os
import re
import shlex
import subprocess
import sys

GUIDANCE = (
    "作業ツリーの変更を破棄するgitコマンドは禁止されています。 (matched: {reason})\n"
    "自分が行っていない変更はユーザーが手動で加えたものとみなし、破棄・差し戻しをしないでください。\n"
    "破棄が本当に必要な場合は、対象と理由をユーザーに伝え、"
    "`!git restore ...` などをユーザー自身に実行してもらってください。"
)

STASH_READONLY = {"list", "show"}

# `git checkout` options that create a branch and consume the next token as its name
CHECKOUT_CREATE_OPTS = {"-b", "-B", "--orphan"}

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


def git_subcommand(tokens: list[str], cwd: str) -> tuple[str, list[str], str] | None:
    """Return (subcommand, its args, directory git runs in)."""
    if not tokens or tokens[0] != "git":
        return None
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if not tok.startswith("-"):
            return tok, tokens[i + 1 :], cwd
        if tok == "-C" and i + 1 < len(tokens):
            cwd = os.path.join(cwd, os.path.expanduser(tokens[i + 1]))
        if "=" not in tok and tok in OPTS_WITH_ARG:
            i += 2
        else:
            i += 1
    return None


def is_commit(rev: str, cwd: str) -> bool:
    try:
        return (
            subprocess.run(
                ["git", "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}"],
                cwd=cwd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
            ).returncode
            == 0
        )
    except (OSError, subprocess.SubprocessError):
        return False  # unresolvable (e.g. wrong cwd after `cd`): treat as pathspec


def checkout_restores_files(args: list[str], cwd: str) -> bool:
    # Branch switching is handled by ask-branch-checkout.py; here only the
    # file-restore forms, classified the same way git itself does.
    if any(a in CHECKOUT_CREATE_OPTS for a in args):
        return False  # git rejects -b/-B/--orphan combined with paths
    if "--" in args or any(a.startswith("--pathspec-from-file") for a in args):
        return True
    nonflags = [a for a in args if not a.startswith("-")]
    if len(nonflags) >= 2:
        return True  # git checkout <tree-ish> <pathspec>
    # A lone argument is a ref if git can resolve it, otherwise a pathspec.
    return len(nonflags) == 1 and not is_commit(nonflags[0], cwd)


def discard_reason(sub: str, args: list[str], cwd: str) -> str | None:
    flags = [a for a in args if a.startswith("-")]
    nonflags = [a for a in args if not a.startswith("-")]

    if sub == "checkout":
        if checkout_restores_files(args, cwd):
            return "git checkout <pathspec>"
    elif sub == "restore":
        staged_only = any(f in ("--staged", "-S") for f in flags) and not any(
            f in ("--worktree", "-W") for f in flags
        )
        if not staged_only:  # --staged alone only unstages; worktree is untouched
            return "git restore"
    elif sub == "reset":
        if "--hard" in flags:
            return "git reset --hard"
    elif sub == "stash":
        if not nonflags or nonflags[0] not in STASH_READONLY:
            return "git stash"
    elif sub == "clean":
        short = "".join(f[1:] for f in flags if not f.startswith("--"))
        forced = "f" in short or "--force" in flags
        dry_run = "n" in short or "--dry-run" in flags
        if forced and not dry_run:
            return "git clean -f"
    return None


def find_discard(command: str, cwd: str) -> str | None:
    for segment in split_segments(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        parsed = git_subcommand(tokens, cwd)
        if not parsed:
            continue
        reason = discard_reason(*parsed)
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
        reason = find_discard(command, data.get("cwd") or os.getcwd())
    except Exception:
        return 0

    if reason:
        print(GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
