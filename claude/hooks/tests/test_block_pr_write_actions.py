"""Tests for block-pr-write-actions.py.

The hook is started as a subprocess, as Claude Code does, and judged by its
contract: exit code 2 blocks, permissionDecision "ask" on stdout prompts, and
exit code 0 with empty stdout lets the command through.

Run from the repository root:
    python3 -m unittest discover -s claude/hooks/tests -v
"""
import glob
import json
import os
import subprocess
import sys
import time
import unittest

CLAUDE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, os.pardir)
HOOK = os.path.join(CLAUDE_DIR, "hooks", "block-pr-write-actions.py")

M = "gh pr merge 1 --admin"
PIN = "gh pr merge 1 --match-head-commit abc1234"

# Risk 3: real PR writes in bash that the plain string match let through
# (Issue #53, "Ways around it"). (why, command)
WAYS_AROUND = [
    ("single & after a pinned merge", PIN + " & " + M),
    (
        "single & after an allowed POST",
        "gh api -X POST repos/o/r/issues/1/comments -F body=@b.md & gh api -X PUT repos/o/r/pulls/1/merge",
    ),
    ("newline after a pinned merge", PIN + "\n" + M),
    ("method inside combined short flags", "gh api -iXPUT repos/o/r/pulls/1/merge"),
    ("field value attached to -f", "gh api repos/o/r/issues/1/labels -flabels[]=x"),
    ("-fX=GET is a field, not the method", "gh api repos/o/r/issues/1/labels -flabels[]=bug -fX=GET"),
    ("command word split by empty quotes", "g''h pr merge 1"),
    ("quoted subcommand", 'gh "pr" merge 1'),
    ("backslash inside the command word", "g\\h pr merge 1"),
    ("ANSI-C quoted subcommand", "gh $'pr' merge 1"),
    ("empty parameter inside the subcommand", "gh pr mer${X}ge 1"),
    ("brace expansion yielding the subcommand", "gh pr {merge,} 1"),
    ("line continuation inside the subcommand", "gh pr mer\\\nge 1 --admin"),
    ("quoted command name under find -exec", "find . -exec 'gh' pr merge 1 \\;"),
    ("pin only inside --body", "gh pr merge 1 --admin --body ' --match-head-commit abc1234'"),
    ("pin only after #", "gh pr merge 1 --admin # --match-head-commit abc1234"),
    ("pin behind an escaped quote", 'gh pr merge 1 --squash --body "a\\" --match-head-commit abc1234 \\""'),
    ("pin overridden by a later empty value", "gh pr merge 1 --squash --match-head-commit abc1234 --match-head-commit="),
    ("pin consumed as the value of --subject", "gh pr merge --squash --subject --match-head-commit 1234567"),
    ("alias renaming a blocked command", "gh alias set mm 'pr merge' && gh mm 1"),
    ("GraphQL query from a file", "gh api graphql -F query=@q.graphql"),
    ("GraphQL query from a file, attached", "gh api graphql -Fquery=@q.graphql"),
    ("GraphQL query from a command substitution", 'gh api graphql -f query="$(cat q.graphql)"'),
    ("flag before graphql", "gh api -H 'X: y' graphql -f query='mutation { x }'"),
    ("path built from a variable", 'R=o/r; gh api -X PUT "repos/$R/pulls/1/merge"'),
    ("flags injected by word splitting", 'EP="repos/o/r/pulls/1/merge -X PUT"; gh api $EP'),
    ("flags injected by brace expansion", "gh api repos/o/r/pulls/1/merge {-X,PUT}"),
    ("{var}> redirection is not an argument", "gh pr {fd}>/dev/null merge 1 --admin"),
    ("command name from a variable", "X=gh; $X pr merge 1 --admin"),
    ("command name from a glob", "/usr/bin/g[h] pr merge 1 --admin"),
    ("subcommand given to gh by xargs", "printf '%s\\n' pr merge 1 --admin | xargs gh"),
    ("GraphQL through an absolute URL", "gh api https://api.github.com/graphql -f query='mutation { x }'"),
]

# Risk 2: everyday commands that only mention gh with an expansion. (why, command)
DAILY = [
    ("commit message naming a read with $N", "git commit -m 'docs: use gh pr view $N for the check'"),
    ("braces in a mentioned path", "echo 'run gh api repos/o/r/{a,b}'"),
]

# Risk 1: inputs that once made the argument check quadratic; a hook that times
# out lets the command through. (why, expected verdict, command)
SLOW_INPUTS = [
    ("many gh words, then a merge", "block", "gh " * 40000 + M),
    ("many gh words, then a pinned merge", "ask", "gh " * 40000 + PIN),
]

# Risk 1: forms main already blocks that broke the reverted regex versions in
# #52; the parser must read them as bash does. (why, command)
PARSER_TRAPS = [
    ("quote inside a comment must not hide the next line", "echo start # it's\n" + M + "\n# don't"),
    ("indented line is not the heredoc terminator", "cat <<'EOF'\n  EOF\n'\nEOF\n" + M + "\n# '"),
    ("-sX inside a quoted body is not the method", "gh api repos/o/r/pulls -f title=t -f 'body=curl -sX GET http://x'"),
    ("unterminated heredoc fed to a shell", "bash <<EOF\n" + M),
    ("quoted text run by trap", "trap '" + M + "' EXIT"),
    ("quoted text run by rebase -x", "git rebase -x '" + M + "' HEAD~1"),
    ("quoted text run by env -S", "env -S '" + M + "'"),
    ("quoted text run as a git ! alias", "git config alias.m '!" + M + "' && git m"),
]

# Risk 2: what the PR skills rely on. (why, expected verdict, command)
SKILL_PATHS = [
    ("review POST", "pass", "gh api -X POST repos/o/r/pulls/1/reviews --input /tmp/body.json"),
    ("thread reply POST", "pass", "gh api -X POST repos/o/r/pulls/1/comments/9/replies -F body=@/tmp/b.md"),
    ("conversation comment POST", "pass", "gh api -X POST repos/o/r/issues/1/comments -F body=@/tmp/b.md"),
    (
        "allowed POST chained with another command",
        "block",
        "cat b.json && gh api -X POST repos/o/r/pulls/1/reviews --input b.json",
    ),
    ("pinned merge", "ask", "gh pr merge 5 --repo o/r --squash --match-head-commit abc1234"),
    (
        "pinned merge with & inside a quoted subject",
        "ask",
        'gh pr merge 5 --repo o/r --squash --subject "Fix A & B" --match-head-commit abc1234',
    ),
    ("gh pr view", "pass", "gh pr view 5 --json title"),
    ("gh pr diff", "pass", "gh pr diff 5 --repo o/r"),
    ("gh pr checks", "pass", "gh pr checks 5 --repo o/r"),
    ("GET with a pipe inside --jq", "pass", "gh api repos/o/r/pulls/1/comments --jq '.[] | .body'"),
    ("GET with a glob-like query string", "pass", "gh api repos/o/r/issues?state=open --jq '.[].number'"),
]


def skill_graphql_reads() -> list[str]:
    """The GraphQL read commands written in the skills, with placeholders filled in."""
    commands = []
    for path in glob.glob(os.path.join(CLAUDE_DIR, "skills", "*", "SKILL.md")):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("gh api graphql"):
                    for placeholder, value in (("<owner>", "o"), ("<repo>", "r"), ("<number>", "1")):
                        line = line.replace(placeholder, value)
                    commands.append(line)
    return commands


def run_hook(command: str) -> tuple[str, str]:
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    r = subprocess.run(
        [sys.executable, HOOK], input=payload, capture_output=True, text=True, timeout=30
    )
    if r.returncode == 2:
        return "block", r.stdout
    if r.returncode == 0 and r.stdout:
        decision = json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"]
        return decision, r.stdout
    return ("pass" if r.returncode == 0 else f"exit {r.returncode}"), r.stdout


class BlockPrWriteActionsTest(unittest.TestCase):
    def test_ways_around_are_blocked(self):
        for why, command in WAYS_AROUND:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], "block")

    def test_parser_traps_stay_blocked(self):
        for why, command in PARSER_TRAPS:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], "block")

    def test_skill_commands_keep_working(self):
        for why, expected, command in SKILL_PATHS:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], expected)

    def test_daily_mentions_pass(self):
        for why, command in DAILY:
            with self.subTest(why):
                self.assertEqual(run_hook(command), ("pass", ""))

    def test_large_inputs_finish_in_time(self):
        for why, expected, command in SLOW_INPUTS:
            with self.subTest(why):
                start = time.monotonic()
                verdict = run_hook(command)[0]
                self.assertLess(time.monotonic() - start, 3.0)
                self.assertEqual(verdict, expected)

    def test_skill_graphql_reads_pass(self):
        commands = skill_graphql_reads()
        # Fewer than the four known reads means the extraction broke, not that all pass.
        self.assertGreaterEqual(len(commands), 4)
        for command in commands:
            with self.subTest(command[:80]):
                self.assertEqual(run_hook(command), ("pass", ""))


if __name__ == "__main__":
    unittest.main()
