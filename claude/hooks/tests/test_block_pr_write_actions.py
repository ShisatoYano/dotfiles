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
import unittest

CLAUDE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, os.pardir)
HOOK = os.path.join(CLAUDE_DIR, "hooks", "block-pr-write-actions.py")

PINNED = "gh pr merge 1 --match-head-commit abcdef1"
API_MERGE = "gh api -X PUT repos/o/r/pulls/1/merge"

# Risk 1: spellings of a real write that used to get through. (why, command)
CLOSED_GAPS = [
    (
        "write after an allowed POST, joined by a single &",
        "gh api -X POST repos/o/r/issues/1/comments -F body=@b.md & " + API_MERGE,
    ),
    ("field value attached to -f", "gh api repos/o/r/issues/1/labels -flabels[]=x"),
    ("method inside combined short flags", "gh api -iXPUT repos/o/r/pulls/1/merge"),
    ("method after combined short flags", "gh api -iX PUT repos/o/r/pulls/1/merge"),
    ("second method overrides an allowed POST", "gh api -X POST repos/o/r/pulls/1/reviews -X DELETE"),
    ("command word split by empty quotes", "g''h pr merge 1 --admin"),
    ("quoted subcommand", 'gh "pr" merge 1 --admin'),
    ("backslash inside the command word", "g\\h pr merge 1 --admin"),
    ("line continuation inside the command", "gh pr \\\nmerge 1 --admin"),
    ("quoted command name under find -exec", "find . -maxdepth 0 -exec 'gh' pr merge 1 --admin \\;"),
    ("alias that would rename a blocked command", "gh alias set mm 'pr merge'"),
    ("GraphQL query read from a file can't be inspected", "gh api graphql -F query=@q.graphql"),
    ("unpinned merge after a pinned one, joined by &", PINNED + " & gh pr merge 2 --admin"),
    ("unpinned merge on the line after a pinned one", PINNED + "\ngh pr merge 2 --admin"),
    ("pin that is only text in --body", "gh pr merge 1 --admin --body ' --match-head-commit abcdef1'"),
    ("pin that is only in a comment", "gh pr merge 1 --admin # --match-head-commit abcdef1"),
    ("quoted sha is not accepted as a pin", "gh pr merge 1 --match-head-commit 'abcdef1'"),
]

# Risk 1, other direction: the finer splitting must not hide what the coarse
# one caught. (why, command)
STILL_BLOCKED = [
    ("plain run", "gh pr merge 1 --squash"),
    ("& inside a quoted path", "gh api 'repos/o/r/pulls/1/merge?a=1&b=2' -X PUT"),
    ("mutation on a later line of a quoted query", "gh api graphql -f query='\nmutation { x }'"),
]

# Risk 2: what the PR skills rely on. (why, expected verdict, command)
UNCHANGED = [
    ("review POST", "pass", "gh api -X POST repos/o/r/pulls/1/reviews --input /tmp/body.json"),
    ("thread reply POST", "pass", "gh api -X POST repos/o/r/pulls/1/comments/9/replies -F body=@/tmp/b.md"),
    ("conversation comment POST", "pass", "gh api -X POST repos/o/r/issues/1/comments -F body=@/tmp/b.md"),
    (
        "allowed POST chained with another command",
        "block",
        "cat b.json && gh api -X POST repos/o/r/pulls/1/reviews --input b.json",
    ),
    ("pinned merge", "ask", "gh pr merge 5 --repo o/r --squash --match-head-commit abc1234"),
    ("gh pr view", "pass", "gh pr view 5 --json title"),
    ("gh pr diff", "pass", "gh pr diff 5 --repo o/r"),
    ("gh pr checks", "pass", "gh pr checks 5 --repo o/r"),
    ("comment list", "pass", "gh api repos/o/r/pulls/1/comments"),
    ("stderr redirect is not a separator", "ask", PINNED + " 2>&1"),
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
        [sys.executable, HOOK], input=payload, capture_output=True, text=True
    )
    if r.returncode == 2:
        return "block", r.stdout
    if r.returncode == 0 and r.stdout:
        decision = json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"]
        return decision, r.stdout
    return ("pass" if r.returncode == 0 else f"exit {r.returncode}"), r.stdout


class BlockPrWriteActionsTest(unittest.TestCase):
    def test_closed_gaps_are_blocked(self):
        for why, command in CLOSED_GAPS:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], "block")

    def test_coarse_matches_stay_blocked(self):
        for why, command in STILL_BLOCKED:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], "block")

    def test_skill_commands_are_unchanged(self):
        for why, expected, command in UNCHANGED:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], expected)

    def test_skill_graphql_reads_pass(self):
        commands = skill_graphql_reads()
        # Fewer than the four known reads means the extraction broke, not that all pass.
        self.assertGreaterEqual(len(commands), 4)
        for command in commands:
            with self.subTest(command[:80]):
                self.assertEqual(run_hook(command), ("pass", ""))


if __name__ == "__main__":
    unittest.main()
