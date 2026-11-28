"""Tests for block-pr-write-actions.py.

The hook is started as a subprocess, as Claude Code does, and judged by its
contract: exit code 2 blocks, permissionDecision "ask" on stdout prompts, and
exit code 0 with empty stdout lets the command through.

Run from the repository root:
    python3 -m unittest discover -s claude/hooks/tests -v
"""
import json
import os
import subprocess
import sys
import unittest

HOOK = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "block-pr-write-actions.py"
)

INERT_COMMIT = "git commit -m \"$(cat <<'EOF'\n{body}\nEOF\n)\""

# Risk 1: a real gh run slips through. (why the case is needed, command)
BLOCKED = [
    ("plain run", "gh pr merge 5 --squash"),
    ("run after another command", "cd repo && gh pr review 5 --approve"),
    ("run behind an env prefix", "env GH_TOKEN=x gh pr comment 5 -b hi"),
    ("quoted text handed to a shell", 'bash -c "gh pr merge 5 --squash"'),
    ("heredoc handed to a shell", "bash <<EOF\ngh pr merge 5\nEOF"),
    ("command substitution inside quotes", 'echo "$(gh pr merge 5)"'),
    ("mutation only visible inside quotes", "gh api graphql -f query='mutation { x }'"),
    ("quoted method and path", 'gh api -X "DELETE" "repos/o/r/issues/1/labels/x"'),
    ("quoted path, method after it", "gh api 'repos/o/r/pulls/1/merge' -X PUT"),
    ("implicit POST through a field", "gh api repos/o/r/issues -f title=x"),
    ("unclosed quote must not fail open", 'gh pr merge 5 "unclosed'),
    ("unterminated heredoc must not fail open", "cat <<EOF\ntext\ngh pr merge 5"),
    (
        "unquoted heredoc delimiter still expands its body",
        'git commit -m "$(cat <<EOF\n$(gh pr merge 5)\nEOF\n)"',
    ),
    ("run after the inert commit form", INERT_COMMIT.format(body="msg") + " && gh pr merge 5"),
    (
        "inert form that only looks so inside single quotes",
        "echo '$(cat <<'EOF'\n' ; gh pr merge 5 ; echo '\nEOF\n)'",
    ),
    ("heredoc handed to an interpreter", "python3 <<'EOF'\nos.system('gh pr merge 5')\nEOF"),
    ("quoted text run through a variable", 'x="gh pr merge 5"; $x'),
]

# Risk 2: what pr-workflow relies on changes. (why, expected verdict, command)
UNCHANGED = [
    (
        "allowed review POST on its own",
        "pass",
        "gh api -X POST repos/o/r/pulls/1/reviews --input body.json",
    ),
    (
        "allowed POST chained with another command",
        "block",
        "cat body.json && gh api -X POST repos/o/r/pulls/1/reviews --input body.json",
    ),
    (
        "merge pinned to a head commit",
        "ask",
        "gh pr merge 5 --repo o/r --squash --match-head-commit abc1234",
    ),
    ("read with a pipe inside --jq", "pass", "gh api repos/o/r/pulls/1/comments --jq '.[] | .body'"),
    ("read through gh pr", "pass", "gh pr view 5 --json title"),
]

# Risk 3: text that only mentions the commands is still stopped. (why, command)
MENTION_ONLY = [
    ("commit message in double quotes", 'git commit -m "docs: explain gh pr merge rule"'),
    ("text in single quotes", "echo 'gh pr review is blocked' >> notes.md"),
    ("heredoc body written to a file", "cat <<EOF > f.md\nuse gh pr merge with care\nEOF"),
    ("search pattern", 'grep -rn "gh pr comment" claude/'),
    ("gh api write as a search pattern", 'git log --grep="gh api -X POST repos/o/r/pulls/1/merge"'),
    ("argument to a script", "python3 run_cases.py 'gh pr merge 5'"),
    (
        "pinned merge in a message must not prompt",
        'git commit -m "run gh pr merge 5 --match-head-commit abc1234"',
    ),
    (
        "allowed POST in a message, chained",
        'echo "gh api -X POST repos/o/r/pulls/1/reviews --input x" && ls',
    ),
    (
        "usual commit form, body also naming a shell",
        INERT_COMMIT.format(body="explain gh pr merge\n\nbash is mentioned too"),
    ),
]


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
    def test_real_runs_are_blocked(self):
        for why, command in BLOCKED:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], "block")

    def test_allowed_and_asked_paths_are_unchanged(self):
        for why, expected, command in UNCHANGED:
            with self.subTest(why):
                self.assertEqual(run_hook(command)[0], expected)

    def test_mentions_pass_silently(self):
        for why, command in MENTION_ONLY:
            with self.subTest(why):
                self.assertEqual(run_hook(command), ("pass", ""))


if __name__ == "__main__":
    unittest.main()
