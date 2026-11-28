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

Two checks run and the stricter verdict wins, so adding the second can't
weaken the first; it only runs when the regex check hasn't already blocked.
The regex check matches the raw command text (it also blocks text that only
mentions these commands). The argument-level check splits the command the
way bash does (quotes, $'...', escapes, comments, line continuations,
heredocs, {var}> redirections, &, newlines) and reads gh's flags the way
pflag does (-iXPUT, -fX=GET, last value wins). gh is gh wherever it
appears. A path ending in /gh is gh where a command runs (after assignments
and wrappers such as env, nice or timeout, or as what xargs runs) and a
possible gh elsewhere. A word built from an expansion or glob ($X, $(...),
{gh,}, g[h]) where a command runs or followed (flags skipped) by a gh
subcommand is a possible gh too; when a possible gh's subcommand is an
expansion as well, a literal merge/review/comment/alias after it, or the
name spelling gh, still blocks. The one exception: in a simple command
named grep, egrep, fgrep, rg (without --pre) or git grep/log/show/diff
(without -c/--config-env/--exec-path, or grep -O), gh among the arguments
is a search word, unless the command redefines one of these as a function.

On top of the above it blocks `gh alias set/import`, a GraphQL query
(including one sent to an absolute .../graphql URL) read from a file or an
expansion, a decisive word built from an expansion, word splitting or
braces before gh's subcommand or action (--repo $X), a merge whose last
--match-head-commit is not a literal hex sha, gh run by xargs without its
subcommand, gh api with two or more positional words of which one starts
with an expansion (even quoted, "$M" may be -XPUT), gh api with an
expansion among a flag's letters (-"$M"), and, for writes only (gh api to a
PR path or graphql, gh pr merge), an argument that word splitting or a
brace starting with "-" could turn into extra flags; reads such as
`gh pr view $N` are left alone. Quoted text, substitutions, heredoc bodies
and env -S values are checked again as commands (trap, -c, rebase -x,
git ! aliases), up to MAX_DEPTH levels; deeper nesting blocks. Running past
TIME_LIMIT blocks; any other exception leaves the regex verdict alone.

Exit 2 blocks the tool call and feeds stderr back to the model (Claude Code
PreToolUse hook contract). Any unexpected error here fails open (exit 0) so a
bug in this script can't break every Bash call.
"""
import json
import re
import sys
import time

GUIDANCE = (
    "PRの状態を変更する操作(gh pr merge/review/comment、およびgh api経由の同等操作)は禁止されています。 "
    "(matched: {reason})\n"
    "レビュー送信・返信は gh api -X POST の reviews / comments/<id>/replies / issues/<n>/comments のみ許可されています。"
    "マージは gh pr merge <n> --repo <owner/repo> <方式> --match-head-commit <マージ可否チェック時のhead> の形でのみ、ユーザー承認つきで許可されています。"
    "それ以外の操作は、判断材料を提示してユーザー自身に行ってもらってください。"
    "コマンドの文字列として含むだけ(コミットメッセージ・本文など)でもブロックされるので、本文はWriteツールでファイルに書き、`git commit -F <file>` などファイルで渡してください。"
    "gh を検索語にして止まった場合は、grep・rg・git grep/log をコマンドの先頭に置く(ラッパーを挟まない)か `git ls-files | xargs grep -lw gh` の形にし、gh api のエンドポイントの変数は \"repos/$R/...\" のように引用符で囲んでください。"
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


# --- Argument-level check -------------------------------------------------
# Splits the command into words the way bash does and inspects gh's
# arguments. It only ever adds blocks/asks to the regex checks above.

PASS, ASK, BLOCK = 0, 1, 2
MAX_DEPTH = 8
# A hook that times out lets the command through, so running out of time blocks.
TIME_LIMIT = 2.0

# pflag value-taking flags. -i is gh api's --include (a boolean), so it is not here.
API_SHORT = {"X": "method", "f": "raw-field", "F": "field", "H": "header",
             "p": "preview", "q": "jq", "t": "template", "R": "repo"}
API_LONG = {"method", "raw-field", "field", "header", "input", "preview", "jq",
            "template", "cache", "hostname", "repo"}
MERGE_SHORT = {"t": "subject", "b": "body", "F": "body-file", "A": "author-email", "R": "repo"}
MERGE_LONG = {"subject", "body", "body-file", "author-email", "match-head-commit", "repo"}
ANY_SHORT = {c: c for c in "XfFHpqtbAR"}
ANY_LONG = API_LONG | MERGE_LONG | {"json", "color", "interval"}

HEX_SHA = re.compile(r"[0-9a-f]{7,40}")
PR_SEGMENT = re.compile(r"(?:^|/)(?:pulls|issues)(?:[/?#]|$)")
ALLOWED_ENDPOINT = re.compile(
    r"repos/[^/]+/[^/]+/"
    r"(?:pulls/\d+/reviews|pulls/\d+/comments/\d+/replies|issues/\d+/comments)"
)
# gh api uses an endpoint containing "://" as an absolute URL.
URL_PREFIX = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://[^/]*")
NEEDS_PARSE = re.compile(r"[\s;&|()<>$`'\"\\{}#]")
SHELL_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-]")
FD_VARIABLE = re.compile(r"\{[A-Za-z_][A-Za-z0-9_]*\}")
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\[[^\]]*\])?\+?=")
RESERVED = {"!", "if", "then", "else", "elif", "while", "until", "do", "coproc"}
# Commands that run the command after them, with their options that take a value.
WRAPPERS = {"env": "uCS", "command": "", "exec": "a", "nohup": "", "nice": "n",
            "timeout": "sk", "stdbuf": "ioe", "time": "fo", "sudo": "ugCDhprtUT",
            "setsid": "", "ionice": "cnp"}
# Commands that only search text, so a gh among their arguments is a search
# word (grep -lw gh $(git ls-files)). Not when they can run a command.
SEARCHERS = {"grep", "egrep", "fgrep", "rg"}
GIT_SEARCHES = {"grep", "log", "show", "diff"}
GIT_VALUE_OPTIONS = {"-C", "--git-dir", "--work-tree", "--namespace", "--super-prefix"}
REDEFINED_SEARCHER = re.compile(
    r"\bfunction\s+(?:grep|egrep|fgrep|rg|git)\b|(?<![\w-])(?:grep|egrep|fgrep|rg|git)\s*\(\s*\)"
)
# gh as a word of its own: ${x:-gh}, $(which gh), not ghq or highlight.
GH_TOKEN = re.compile(r"(?<![A-Za-z0-9_])gh(?![A-Za-z0-9_-])")
GH_SUBCOMMANDS = {"pr", "api", "alias"}
GH_ACTIONS = {"merge", "review", "comment", "alias"}
# xargs/parallel options that take the next word as their value.
XARGS_SHORT = set("adEILnPsj")
XARGS_LONG = {"arg-file", "delimiter", "eof", "replace", "max-lines", "max-args",
              "max-procs", "max-chars", "process-slot-var", "jobs"}
REDIRECTS = ("<<<", "<<-", "<<", "<>", "<&", "<", ">>", ">&", ">|", ">")
ANSI_C_ESCAPE = re.compile(r"\\(x[0-9A-Fa-f]{1,2}|u[0-9A-Fa-f]{1,4}|U[0-9A-Fa-f]{1,8}|[0-7]{1,3}|c.|.)", re.S)
ANSI_C_SIMPLE = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f",
                 "v": "\v", "e": "\x1b", "E": "\x1b"}


class OutOfTime(Exception):
    pass


class Run:
    deadline = float("inf")
    searchers_trusted = True  # false when the command redefines one as a function

    @classmethod
    def check_time(cls) -> None:
        if time.monotonic() > cls.deadline:
            raise OutOfTime


class Word:
    def __init__(self) -> None:
        self.chars: list[str] = []
        self.quoted = False
        self.expands = False  # parameter expansion or substitution, quoted or not
        self.splits = False  # one outside quotes: word splitting may turn it into several words
        self.brace = False  # brace expansion: {a,b} or {1..3}
        self.brace_flag = False  # ...with an alternative starting with "-", which can inject a flag
        self.glob = False  # unquoted * ? [
        self.starts_expanded = False  # begins with an expansion, quoted or not: "$M" may be -XPUT
        self.flag_expanded = False  # an expansion among a "-" word's flag letters: -"$M"
        self.braces: list[list[bool]] = []  # open unquoted "{": [has "," or "..", has "-" alternative]
        self._lead = ""

    @property
    def lead(self) -> str:
        """First character of the word; cached since it can't change once set."""
        if not self._lead:
            self._lead = next((c[0] for c in self.chars if c), "")
        return self._lead

    def brace_among_flag_letters(self) -> bool:
        """Whether the first "{" of a "-" word sits among flag letters, where its
        expansion can make a flag (-{p,X}PUT -> -XPUT), rather than in a flag's
        value (-H{a,b} is the value of -H)."""
        return self.lead == "-" and among_flag_letters(self.head().split("{", 1)[0])

    def head(self) -> str:
        prefix, size = [], 0
        for chunk in self.chars:  # bounded so a long word stays linear
            prefix.append(chunk)
            size += len(chunk)
            if size > 64:
                break
        return "".join(prefix)[:64]

    @property
    def value(self) -> str:
        return "".join(self.chars)

    @property
    def unsafe(self) -> bool:
        """bash may turn this word into something other than its text."""
        return self.expands or self.brace or self.glob

    @property
    def injects(self) -> bool:
        """bash may turn this word into extra words, flags included."""
        return self.splits or self.brace_flag

    def mark_expansion(self, in_quotes: bool) -> None:
        # Called before the expansion's text is added, so no text yet means it leads.
        self.starts_expanded = self.starts_expanded or not self.lead
        # -"$M" with M=XPUT is -XPUT: an expansion among flag letters builds a flag.
        if not self.flag_expanded and self.lead == "-":
            self.flag_expanded = among_flag_letters(self.head())
        self.expands = True
        self.splits = self.splits or not in_quotes


def among_flag_letters(head: str) -> bool:
    """Whether the end of head, the start of a "-" word, is still among flag
    letters rather than in the value of a flag that takes one."""
    if head.startswith("--"):
        return "=" not in head
    return not any(c in ANY_SHORT for c in head[1:])


def ansi_c(text: str) -> str:
    def decode(m: re.Match) -> str:
        e = m.group(1)
        if e[0] in "xuU":
            return chr(min(int(e[1:], 16), 0x10FFFF))
        if e[0] in "01234567":
            return chr(int(e, 8))
        if e[0] == "c":
            return chr(ord(e[1]) & 0x1F)
        return ANSI_C_SIMPLE.get(e, e)
    return ANSI_C_ESCAPE.sub(decode, text)


def skip_quoted(src: str, i: int) -> int:
    quote, j = src[i], i + 1
    while j < len(src):
        if quote == '"' and src[j] == "\\":
            j += 2
            continue
        if src[j] == quote:
            return j + 1
        j += 1
    return len(src)


def find_close(src: str, i: int, opener: str, closer: str) -> int:
    """Index of the closer matching an opener just before i (len(src) if none)."""
    depth = 1
    while i < len(src):
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c in "'\"":
            i = skip_quoted(src, i)
            continue
        if c == opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(src)


def find_backtick(src: str, i: int) -> int:
    while i < len(src):
        if src[i] == "\\":
            i += 2
            continue
        if src[i] == "`":
            return i
        i += 1
    return len(src)


def read_dollar(src: str, i: int, word: Word, nested: list[str], in_quotes: bool) -> int:
    """Read a $-form at src[i] into word; return the index after it."""
    nxt = src[i + 1] if i + 1 < len(src) else ""
    if nxt == "(":
        j = find_close(src, i + 2, "(", ")")
        nested.append(src[i + 2 : j])
    elif nxt == "{":
        j = find_close(src, i + 2, "{", "}")
        nested.append(src[i + 2 : j])
    elif nxt == "'" and not in_quotes:
        j = i + 2
        while j < len(src) and src[j] != "'":
            j += 2 if src[j] == "\\" else 1
        word.quoted = True
        word.chars.append(ansi_c(src[i + 2 : j]))
        return j + 1
    elif nxt == '"' and not in_quotes:
        return read_double(src, i + 2, word, nested)
    else:
        m = SHELL_NAME.match(src, i + 1)
        if not m:
            word.chars.append("$")
            return i + 1
        j = m.end() - 1
    word.mark_expansion(in_quotes)
    word.chars.append(src[i : j + 1])
    return j + 1


def read_double(src: str, i: int, word: Word, nested: list[str]) -> int:
    """Read a double-quoted span starting after its opening quote."""
    word.quoted = True
    while i < len(src):
        c = src[i]
        if c == '"':
            return i + 1
        if c == "\\":
            nxt = src[i + 1] if i + 1 < len(src) else ""
            if nxt == "\n":
                i += 2
            elif nxt in ("$", "`", '"', "\\"):
                word.chars.append(nxt)
                i += 2
            else:
                word.chars.append("\\")
                i += 1
        elif c == "$":
            i = read_dollar(src, i, word, nested, in_quotes=True)
        elif c == "`":
            j = find_backtick(src, i + 1)
            nested.append(src[i + 1 : j])
            word.mark_expansion(in_quotes=True)
            word.chars.append(src[i : j + 1])
            i = j + 1
        else:
            word.chars.append(c)
            i += 1
    return len(src)


def split_commands(src: str) -> tuple[list[list[Word]], list[str]]:
    """Split src into simple commands the way bash does. Also return texts
    bash may run as commands: substitutions, heredoc and here-string bodies,
    and redirection targets. Unclosed quotes or substitutions run to the end."""
    commands: list[list[Word]] = []
    nested: list[str] = []
    state = {"cmd": [], "word": None, "expect": None}
    heredocs: list[tuple[str, bool]] = []

    def cur() -> Word:
        if state["word"] is None:
            state["word"] = Word()
        return state["word"]

    def end_word() -> None:
        word, expect = state["word"], state["expect"]
        if word is None:
            return
        state["word"] = state["expect"] = None
        if expect and expect[0] == "heredoc":
            heredocs.append((word.value, expect[1]))
        elif expect:
            nested.append(word.value)
        elif word.value in ("{", "}") and not word.quoted:
            end_command()
        else:
            state["cmd"].append(word)

    def end_command() -> None:
        end_word()
        if state["cmd"]:
            commands.append(state["cmd"])
        state["cmd"], state["expect"] = [], None

    def read_heredoc_bodies(i: int) -> int:
        for delimiter, strip_tabs in heredocs:
            lines = []
            while i < len(src):
                Run.check_time()
                end = src.find("\n", i)
                end = len(src) if end < 0 else end
                line = src[i:end]
                i = end + 1
                # bash ends a heredoc only on a line that is exactly the delimiter.
                if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                    break
                lines.append(line)
            nested.append("\n".join(lines))
        heredocs.clear()
        return i

    i, n = 0, len(src)
    while i < n:
        Run.check_time()
        c = src[i]
        if c == "\\":
            if src.startswith("\\\n", i):
                i += 2
                continue
            word = cur()
            word.quoted = True
            word.chars.append(src[i + 1 : i + 2])
            i += 2
        elif c == "'":
            j = src.find("'", i + 1)
            j = n if j < 0 else j
            word = cur()
            word.quoted = True
            word.chars.append(src[i + 1 : j])
            i = j + 1
        elif c == '"':
            i = read_double(src, i + 1, cur(), nested)
        elif c == "$":
            i = read_dollar(src, i, cur(), nested, in_quotes=False)
        elif c == "`":
            j = find_backtick(src, i + 1)
            nested.append(src[i + 1 : j])
            word = cur()
            word.mark_expansion(in_quotes=False)
            word.chars.append(src[i : j + 1])
            i = j + 1
        elif c in " \t":
            end_word()
            i += 1
        elif c == "#" and state["word"] is None:
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif c == "\n":
            end_command()
            i = read_heredoc_bodies(i + 1)
        elif c in "<>" and src.startswith("(", i + 1):
            j = find_close(src, i + 2, "(", ")")
            nested.append(src[i + 2 : j])
            word = cur()
            word.mark_expansion(in_quotes=False)
            word.chars.append(src[i : j + 1])
            i = j + 1
        elif c in "<>" or src.startswith("&>", i):
            word = state["word"]
            if word is not None and not word.quoted and (
                word.value.isdigit() or FD_VARIABLE.fullmatch(word.value)
            ):
                state["word"] = None  # fd number or {varname}, e.g. 2>&1, {fd}>file
            else:
                end_word()
            op = "&>>" if src.startswith("&>>", i) else "&>" if c == "&" else next(
                r for r in REDIRECTS if src.startswith(r, i)
            )
            i += len(op)
            if op in ("<<", "<<-"):
                state["expect"] = ("heredoc", op == "<<-")
            else:
                state["expect"] = ("target",)
        elif c in ";&|()":
            end_command()
            i += 1
        else:
            word = cur()
            word.chars.append(c)
            # Brace expansion is tracked in this one pass; a look-ahead per "{"
            # made a run of them quadratic.
            dash_next = src.startswith("-", i + 1)
            if c == "{":
                word.braces.append([False, dash_next or word.brace_among_flag_letters()])
            elif word.braces and c == ",":
                word.braces[-1][0] = True
                word.braces[-1][1] = word.braces[-1][1] or dash_next
            elif word.braces and src.startswith("..", i):
                word.braces[-1][0] = True
            elif c == "}" and word.braces:
                has_separator, injects = word.braces.pop()
                if has_separator:
                    word.brace = True
                    word.brace_flag = word.brace_flag or injects
            elif c in "*?[":
                word.glob = True
            i += 1
    end_command()
    return commands, nested


def parse_flags(args: list[Word], start: int, short: dict, long: set,
                stop_after: int = 0) -> tuple[list, list[Word]]:
    """Read args[start:] as pflag does: (name, value text, word holding it)
    for each flag, and the positional words (up to stop_after if given)."""
    flags, positional = [], []
    i = start
    while i < len(args):
        Run.check_time()
        word, arg = args[i], args[i].value
        i += 1
        if arg == "--":
            end = i + stop_after - len(positional) if stop_after else len(args)
            positional.extend(args[i:end])
            break
        if arg == "-" or not arg.startswith("-"):
            positional.append(word)
            if stop_after and len(positional) >= stop_after:
                break
            continue
        if arg.startswith("--"):
            name, eq, value = arg[2:].partition("=")
            if name not in long:
                flags.append((name, None, word))
            elif eq:
                flags.append((name, value, word))
            elif i < len(args):
                flags.append((name, args[i].value, args[i]))
                i += 1
            else:
                flags.append((name, None, None))
            continue
        rest = arg[1:]
        while rest:
            name = short.get(rest[0])
            if name is None:
                rest = rest[1:]
                continue
            # pflag: -X=PUT drops the "=", -fX=GET gives -f the value "X=GET".
            if len(rest) > 2 and rest[1] == "=":
                flags.append((name, rest[2:], word))
            elif len(rest) > 1:
                flags.append((name, rest[1:], word))
            elif i < len(args):
                flags.append((name, args[i].value, args[i]))
                i += 1
            else:
                flags.append((name, None, None))
            break
    return flags, positional


def endpoint_path(value: str) -> str:
    path = URL_PREFIX.sub("", value)
    return re.split(r"[?#]", path, 1)[0].strip("/")


def judge_api(args: list[Word], start: int, injects: bool, alone: bool) -> tuple[int, str]:
    flags, positional = parse_flags(args, start, API_SHORT, API_LONG)
    if len(positional) < 2:
        return (BLOCK, "gh api endpoint may come from an expansion") if injects else (PASS, "")
    endpoint = positional[1]
    path = endpoint_path(endpoint.value)
    # A word starting with an expansion can be a whole flag even when quoted
    # ("$M" with M=-XPUT). A lone such word only loses gh its endpoint, and as an
    # endpoint it is blocked below for anything but GET, so it needs a second one.
    if len(positional) > 2 and any(w.starts_expanded for w in positional[1:]):
        return BLOCK, "gh api argument may be a flag taken from an expansion"
    if any(args[k].flag_expanded for k in range(start, len(args))):
        return BLOCK, "gh api flag built from an expansion"
    if injects:
        # Injected words (e.g. -X PUT) only matter if they can reach the
        # endpoint or the endpoint is one a write could change a PR through.
        end = next(k for k in range(start, len(args)) if args[k] is endpoint)
        if any(args[k].injects for k in range(start, end + 1)):
            return BLOCK, "gh api endpoint may come from an expansion"
        if PR_SEGMENT.search(path) or path == "graphql" or path.endswith("/graphql"):
            return BLOCK, "gh api argument expanded outside quotes"
    methods = [(text, word) for name, text, word in flags if name == "method"]
    fields = [(text, word) for name, text, word in flags if name in ("field", "raw-field")]
    has_input = any(name == "input" for name, _, _ in flags)
    if methods:
        text, word = methods[-1]
        if text is None or word.expands or word.brace:
            return BLOCK, "gh api method not fixed"
        method = text.upper()
    else:
        method = "POST" if fields or has_input else "GET"

    if path == "graphql" or path.endswith("/graphql"):
        if has_input:
            return BLOCK, "gh api graphql --input"
        for text, word in fields:
            if text is not None and text.startswith("query="):
                query = text[len("query="):]
                if word.expands or word.brace or query.startswith("@") or MUTATION.search(query):
                    return BLOCK, "gh api graphql query is a mutation or can't be read"
        return PASS, ""
    if method == "GET":
        return PASS, ""
    if endpoint.expands or endpoint.brace:
        return BLOCK, "gh api write to an endpoint built from an expansion"
    if PR_SEGMENT.search(path):
        if method == "POST" and ALLOWED_ENDPOINT.fullmatch(path):
            if alone:
                return PASS, ""
            return BLOCK, "allowed POST combined with other commands"
        return BLOCK, f"gh api {method} {endpoint.value}"
    return PASS, ""


def judge_gh(args: list[Word], start: int, injects: bool, alone: bool, via_xargs: bool,
             inferred: bool = False) -> tuple[int, str]:
    """Verdict for gh run with args[start:]. injects: one of them may expand
    into extra words; via_xargs: xargs may append more from its input;
    inferred: the command word was only possibly gh (an expansion)."""
    _, positional = parse_flags(args, start, ANY_SHORT, ANY_LONG, stop_after=2)
    undecided = (BLOCK if via_xargs else PASS, "gh subcommand left to xargs input")
    if not positional:
        return undecided
    sub = positional[0]
    if sub.unsafe:
        if not inferred:
            return BLOCK, "gh subcommand built from an expansion"
        # A guessed gh with a guessed subcommand: `$EDITOR $FILE` passes, but a
        # literal action later on (`$G $P merge 1`) or an expansion spelling gh
        # (`${x:-gh} "$@"`) does not. A path such as ~/.config/gh $HOME passes.
        name = args[start - 1]
        if (name.unsafe and GH_TOKEN.search(name.value)) or any(
            args[k].value in GH_ACTIONS for k in range(start, len(args))
        ):
            return BLOCK, "gh and its subcommand both built from expansions"
        return PASS, ""
    if sub.value not in GH_SUBCOMMANDS:
        return PASS, ""
    # Word splitting or braces before the subcommand or action can add one
    # (X='o/r merge'; gh pr --repo $X 1); with no action, any word can.
    if sub.value == "api":
        last = sub
    else:
        last = positional[1] if len(positional) > 1 else None
    for k in range(start, len(args)):
        if args[k].splits or args[k].brace:
            return BLOCK, f"gh {sub.value} subcommand may come from an expansion"
        if args[k] is last:
            break
    # Expansions only matter where they can turn into a write; a read such as
    # `gh pr view $N` (also mentioned in commit messages) is left alone.
    if sub.value == "api":
        if via_xargs:
            return BLOCK, "gh api arguments added by xargs"
        return judge_api(args, start, injects, alone)
    if len(positional) < 2:
        return undecided
    action = positional[1]
    if action.unsafe:
        return BLOCK, f"gh {sub.value} subcommand built from an expansion"
    if sub.value == "alias":
        if action.value in ("set", "import"):
            return BLOCK, f"gh alias {action.value}"
        return PASS, ""
    if action.value in ("review", "comment"):
        return BLOCK, f"gh pr {action.value}"
    if action.value == "merge":
        if injects or via_xargs:
            return BLOCK, "gh pr merge argument expanded outside quotes or added by xargs"
        flags, _ = parse_flags(args, start, MERGE_SHORT, MERGE_LONG)
        pins = [(text, word) for name, text, word in flags if name == "match-head-commit"]
        if pins:
            text, word = pins[-1]
            if text is not None and not word.expands and HEX_SHA.fullmatch(text):
                return ASK, ""
        return BLOCK, "gh pr merge without a usable --match-head-commit"
    return PASS, ""


def xargs_command(argv: list[Word], k: int) -> int:
    """Index of the command xargs/parallel at argv[k] runs (-1 if none)."""
    j = k + 1
    while j < len(argv):
        arg = argv[j].value
        if arg == "--":
            return j + 1
        if arg == "-" or not arg.startswith("-"):
            return j
        if arg.startswith("--"):
            j += 2 if "=" not in arg and arg[2:] in XARGS_LONG else 1
        else:
            j += 2 if len(arg) == 2 and arg[1] in XARGS_SHORT else 1
    return -1


def after_wrapper(argv: list[Word], k: int) -> int:
    """Index of the command a wrapper (env, nice, timeout...) at argv[k] runs."""
    wrapper = argv[k].value.rsplit("/", 1)[-1]
    takes_value = WRAPPERS[wrapper]
    j = k + 1
    while j < len(argv):
        arg = argv[j].value
        if arg == "--":
            return j + 1
        if (wrapper == "env" and ASSIGNMENT.match(arg)) or arg == "!":
            j += 1  # time ! gh ...
        elif arg.startswith("-") and arg != "-":
            j += 2 if len(arg) == 2 and arg[1] in takes_value else 1
        elif wrapper == "timeout":
            wrapper = ""  # the duration comes before the command
            j += 1
        else:
            return j
    return -1


def command_positions(argv: list[Word], k: int) -> list[int]:
    """Where commands start from argv[k] on, following wrappers (env gh ...)."""
    positions = []
    while 0 <= k < len(argv):
        positions.append(k)
        word = argv[k]
        if word.unsafe or word.value.rsplit("/", 1)[-1] not in WRAPPERS:
            break
        k = after_wrapper(argv, k)
    return positions


def only_searches(argv: list[Word], name: int) -> bool:
    """Whether the command named at argv[name] is a search that runs nothing:
    grep/egrep/fgrep, rg without --pre, git grep/log/show/diff without global
    -c/--config-env/--exec-path (which can set a pager) or grep -O (pager)."""
    if not Run.searchers_trusted or name >= len(argv) or argv[name].unsafe:
        return False
    tool = argv[name].value.rsplit("/", 1)[-1]
    rest = argv[name + 1 :]
    if tool in ("grep", "egrep", "fgrep"):
        return True
    if tool == "rg":
        return not any(w.value == "--pre" or w.value.startswith("--pre=") for w in rest)
    if tool != "git":
        return False
    j = name + 1
    while j < len(argv) and argv[j].value.startswith("-"):
        arg = argv[j].value
        if argv[j].splits or arg.startswith(("-c", "--config-env", "--exec-path")):
            return False
        j += 2 if arg in GIT_VALUE_OPTIONS else 1
    if j >= len(argv) or argv[j].unsafe or argv[j].value not in GIT_SEARCHES:
        return False
    if argv[j].value == "grep":
        for w in argv[j + 1 :]:
            arg = w.value
            if arg == "--":
                break
            if arg.startswith("--open-files-in-pager") or (
                arg.startswith("-") and not arg.startswith("--") and "O" in arg
            ):
                return False
    return True


def judge_command(argv: list[Word], alone: bool) -> tuple[int, str]:
    n = len(argv)
    injects_from = [False] * (n + 1)
    for k in range(n - 1, -1, -1):
        injects_from[k] = injects_from[k + 1] or argv[k].injects
    name = next(
        (k for k, w in enumerate(argv) if not (ASSIGNMENT.match(w.value) or w.value in RESERVED)),
        n,
    )
    if only_searches(argv, name):
        return PASS, ""
    runs = set(command_positions(argv, name))
    best, xargs_runs = (PASS, ""), set()
    for k, word in enumerate(argv):
        Run.check_time()
        value = word.value
        path_gh = value.endswith("/gh") and not word.unsafe
        # A /gh path is gh where a command runs (/usr/bin/gh $P $A, xargs env
        # ./gh). Elsewhere it, and an expanded word in the command position or
        # before a gh subcommand (flags skipped), may be gh: ls ~/.config/gh
        # $HOME, X=gh; $X pr merge, env $G -R o/r pr merge.
        literal = value == "gh" or (path_gh and (k in runs or k in xargs_runs))
        inferred = not literal and (
            path_gh
            or (word.unsafe and (k in runs or first_positional_is_subcommand(argv, k + 1)))
        )
        if literal or inferred:
            verdict = judge_gh(
                argv, k + 1, injects_from[k + 1], alone, k in xargs_runs, inferred=inferred
            )
            if verdict[0] > best[0]:
                best = verdict
            if best[0] == BLOCK:
                return best
        if value.rsplit("/", 1)[-1] in ("xargs", "parallel"):
            xargs_runs.update(command_positions(argv, xargs_command(argv, k)))
    return best


def env_split_strings(argv: list[Word]) -> list[str]:
    """Values of env -S / --split-string, which env splits and runs as a command."""
    texts = []
    for k, word in enumerate(argv):
        if word.unsafe or word.value.rsplit("/", 1)[-1] != "env":
            continue
        for j in range(k + 1, len(argv)):
            arg = argv[j].value
            if not arg.startswith("-"):
                break
            nxt = argv[j + 1].value if j + 1 < len(argv) else ""
            if arg.startswith("--split-string"):
                _, eq, text = arg.partition("=")
                texts.append(text if eq else nxt)
            elif not arg.startswith("--") and "S" in arg:
                texts.append(arg[arg.index("S") + 1 :] or nxt)
    return texts


def first_positional_is_subcommand(argv: list[Word], start: int) -> bool:
    _, positional = parse_flags(argv, start, ANY_SHORT, ANY_LONG, stop_after=1)
    return bool(positional) and positional[0].value in GH_SUBCOMMANDS


def analyze(src: str, depth: int, seen: set) -> tuple[int, str]:
    """Verdict for src and for every text bash may run from it."""
    Run.check_time()
    if depth > MAX_DEPTH:
        return BLOCK, "nested too deeply to inspect"
    if src in seen:
        return PASS, ""
    seen.add(src)
    commands, nested = split_commands(src)
    alone = depth == 0 and len(commands) == 1
    best = (PASS, "")
    texts = list(nested)
    for argv in commands:
        verdict = judge_command(argv, alone)
        if verdict[0] > best[0]:
            best = verdict
        if best[0] == BLOCK:
            return best
        texts.extend(env_split_strings(argv))
        for word in argv:
            text = word.value[1:] if word.value.startswith("!") else word.value
            if NEEDS_PARSE.search(text):
                texts.append(text)  # quoted text that trap, -c, -x, env -S... may run
    for text in texts:
        verdict = analyze(text, depth + 1, seen)
        if verdict[0] > best[0]:
            best = verdict
        if best[0] == BLOCK:
            return best
    return best


def argv_check(command: str) -> tuple[int, str]:
    Run.deadline = time.monotonic() + TIME_LIMIT
    Run.searchers_trusted = not REDEFINED_SEARCHER.search(command)
    try:
        return analyze(command, 0, set())
    except OutOfTime:
        return BLOCK, "argument check ran out of time"


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
    try:
        argv_level, argv_reason = argv_check(command)
    except Exception:
        argv_level, argv_reason = PASS, ""  # fall back to the regex checks alone
    if argv_level == BLOCK:
        print(GUIDANCE.format(reason=f"{argv_reason}: {command}"), file=sys.stderr)
        return 2
    if merge or argv_level == ASK:
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
