#!/usr/bin/env python3
"""PreToolUse hook (matcher: Bash) that gates `git push`: pushes that can
damage shared history are hard-blocked, every other push asks the user.

Blocked: force pushes (-f/--force*/+refspec), pushes whose destination is the
default branch (main/master or what <remote>/HEAD points to), remote branch
deletion (--delete/:dst/--prune), --all/--branches/--mirror, and pushes whose
destination can't be determined (no refspec while HEAD is detached, or after
a `cd` in the same command, where the hook's cwd is no longer the repo).

Root cause this guards against: `git push` is outward-facing (visible to
others, triggers CI), and a push to the default branch or a force push can't
be cleanly taken back. Detection needs to be robust against quoted/heredoc
text that merely *contains* the words "git push" (e.g. inside a commit
message body) — a real false positive was hit with a plain regex approach —
so this splits on shell operators while protecting quoted spans, then
tokenizes each segment with shlex and inspects the token stream directly.

Exit 2 blocks the tool call and feeds stderr back to the model; printing
permissionDecision "ask" on stdout prompts the user even in auto mode (Claude
Code PreToolUse hook contract). Any unexpected error here fails open (exit 0)
so a bug in this script can't break every Bash call.
"""
import json
import os
import re
import shlex
import subprocess
import sys

BLOCK_GUIDANCE = (
    "この git push は禁止されています。 (matched: {reason})\n"
    "default branch への push・force push・リモートブランチの削除などは自動では実行できません。\n"
    "本当に必要な場合は、対象と理由をユーザーに伝え、`!git push ...` をユーザー自身に実行してもらってください。"
)

ASK_GUIDANCE = "git push にはユーザーの承認が必要です。 (matched: {reason})"

PROTECTED_BRANCHES = {"main", "master"}

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

# git push options that consume the following token as their argument
PUSH_OPTS_WITH_ARG = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}

BLOCKING_LONG_FLAGS = {"--delete", "--prune", "--all", "--branches", "--mirror"}

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


def parse_git_push(tokens: list[str], cwd: str) -> tuple[str, list[str]] | None:
    """Return (effective cwd, push args) if tokens invoke `git push`."""
    if not tokens or tokens[0] != "git":
        return None
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if not tok.startswith("-"):
            return (cwd, tokens[i + 1 :]) if tok == "push" else None
        if tok == "-C" and i + 1 < len(tokens):
            cwd = os.path.join(cwd, os.path.expanduser(tokens[i + 1]))
        if "=" not in tok and tok in OPTS_WITH_ARG:
            i += 2
        else:
            i += 1
    return None


def git_out(cwd: str, *args: str) -> str:
    try:
        r = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def protected_branches(cwd: str, remote: str) -> set[str]:
    branches = set(PROTECTED_BRANCHES)
    head = git_out(cwd, "symbolic-ref", "--short", "-q", f"refs/remotes/{remote}/HEAD")
    if head.startswith(f"{remote}/"):
        branches.add(head[len(remote) + 1 :])
    return branches


def strip_heads(ref: str) -> str:
    return ref[len("refs/heads/") :] if ref.startswith("refs/heads/") else ref


def push_verdict(args: list[str], cwd: str | None) -> tuple[str, str]:
    """Return ("block" | "ask", reason) for the given `git push` args."""
    positional = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            positional.extend(args[i + 1 :])
            break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            if name.startswith("--force"):
                return "block", f"force push ({a})"
            if name in BLOCKING_LONG_FLAGS:
                return "block", a
            i += 2 if "=" not in a and a in PUSH_OPTS_WITH_ARG else 1
            continue
        if a.startswith("-") and len(a) > 1:
            if "f" in a[1:]:
                return "block", f"force push ({a})"
            if "d" in a[1:]:
                return "block", f"delete ({a})"
            i += 2 if a == "-o" else 1
            continue
        positional.append(a)
        i += 1

    remote = positional[0] if positional else "origin"
    refspecs = positional[1:]

    if any(r.startswith("+") for r in refspecs):
        return "block", "force push (+refspec)"
    if any(r.startswith(":") for r in refspecs):
        return "block", "delete (:refspec)"

    if cwd is None:
        if not refspecs:
            return "block", "destination unknown (cwd changed by cd in the same command)"
        protected = set(PROTECTED_BRANCHES)
    else:
        protected = protected_branches(cwd, remote)

    current = git_out(cwd, "symbolic-ref", "--short", "-q", "HEAD") if cwd else ""
    if not refspecs:
        if cwd is None or not current:
            return "block", "destination unknown (detached HEAD)"
        upstream = git_out(
            cwd, "for-each-ref", "--format=%(upstream:lstrip=3)", f"refs/heads/{current}"
        )
        dests = {current, upstream} - {""}
    else:
        dests = set()
        for r in refspecs:
            src, _, dst = r.partition(":")
            dst = dst or src
            if dst == "HEAD":
                if not current:
                    return "block", "destination unknown (detached HEAD)"
                dst = current
            dests.add(strip_heads(dst))

    hit = dests & protected
    if hit:
        return "block", f"push to default branch ({', '.join(sorted(hit))})"
    return "ask", f"push to {', '.join(sorted(dests))}"


def find_git_push(command: str, cwd: str) -> tuple[str, str] | None:
    """Return the strictest verdict over all `git push` segments, if any."""
    result = None
    cwd_changed = False
    for segment in split_segments(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        if tokens and tokens[0] in ("cd", "pushd", "popd"):
            cwd_changed = True
            continue
        parsed = parse_git_push(tokens, cwd)
        if not parsed:
            continue
        decision, reason = push_verdict(parsed[1], None if cwd_changed else parsed[0])
        reason = f"{reason}: {segment}"
        if decision == "block":
            return decision, reason
        result = (decision, reason)
    return result


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        command = data.get("tool_input", {}).get("command", "")
        if not command:
            return 0
        verdict = find_git_push(command, data.get("cwd") or os.getcwd())
    except Exception:
        return 0

    if not verdict:
        return 0
    decision, reason = verdict
    if decision == "block":
        print(BLOCK_GUIDANCE.format(reason=reason), file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": ASK_GUIDANCE.format(reason=reason),
                }
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
