#!/usr/bin/env python3
# D-Bus上の通知(org.freedesktop.Notifications.Notify)をgnome-shellの処理を邪魔せずに
# 横から観測(eavesdrop)し、Slack/Calendar/Gmailに該当するものだけログファイルへ書き出す。
# GNOME側のポップアップ表示自体は別途「設定 > 通知」でアプリごとにオフにする想定。
import html
import json
import os
import re
import subprocess
from datetime import datetime

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

STATE_DIR = os.path.expanduser("~/.local/state/notify-relay")
LOG_PATH = os.path.join(STATE_DIR, "notify.log")
DEBUG_LOG_PATH = os.path.join(STATE_DIR, "debug.log")
# ジャンプ機能の見直しに向けて、カレンダー関連通知だけはactions/hintsも含めた全フィールドを記録する
CALENDAR_DEBUG_LOG_PATH = os.path.join(STATE_DIR, "calendar_debug.log")

# app_nameだけでは判別できない(Chrome経由の通知はすべて"Google Chrome"名義で届くため)、
# summary/bodyに含まれる文字列で判定する。実際の通知を見ながらここを調整していく。
KEYWORDS = {
    "slack": ["slack"],
    "gmail": ["gmail", "@gmail.com", "mail.google.com"],
    "calendar": ["calendar", "予定", "カレンダー"],
}

# カテゴリごとにログの行頭へ付けるアイコン(未指定のカテゴリは何も付けない)
CATEGORY_ICONS = {
    "calendar": "📅",
    "slack": "💬",
    "github": None,  # 後で設定
}

# Gmail通知は送信元がバラバラなので、内容で細分類してアイコンを分ける
GMAIL_SUBCATEGORY_ICONS = {
    "github": "",  # Nerd Font(nf-fa-github)のGitHubロゴ
    "notion": "📝",
    "calendar": "📅",
    "other": "📧",
}
# SlackのGitHub連携通知にも同じアイコンを使う
CATEGORY_ICONS["github"] = GMAIL_SUBCATEGORY_ICONS["github"]

# GitHubからの返信通知は本文に"[オーナー/リポジトリ] ... (PR #番号)"という形で入っている
GMAIL_GITHUB_RE = re.compile(r"\[[\w.\-]+/[\w.\-]+\].*\(pr #\d+\)")
# 上と同じ形からURL組み立て用にオーナー/リポジトリとPR番号を取り出す(大文字小文字を保つ)
GMAIL_GITHUB_PR_RE = re.compile(r"\[([\w.\-]+/[\w.\-]+)\].*\(PR #(\d+)\)", re.IGNORECASE)


def gmail_github_pr_url(text):
    match = GMAIL_GITHUB_PR_RE.search(text)
    if not match:
        return None
    repo, number = match.groups()
    return f"https://github.com/{repo}/pull/{number}"


def gmail_subcategory(text):
    haystack = text.lower()
    if GMAIL_GITHUB_RE.search(haystack):
        return "github"
    if "notion" in haystack:
        return "notion"
    if "招待:" in text or "invitation:" in haystack:
        return "calendar"
    return "other"


# Slackでメンションされた際に本文に含まれる表示名
MENTION_NAME = "@Shisato Yano"

ANSI_RED_BOLD = "\033[1;31m"
ANSI_RESET = "\033[0m"


def classify(app_name, summary, body):
    haystack = f"{app_name} {summary} {body}".lower()
    for label, words in KEYWORDS.items():
        if any(w in haystack for w in words):
            return label
    return None


MRKDWN_LINK_RE = re.compile(r"<(https?://[^|>]+)\|([^>]+)>")
MRKDWN_BARE_LINK_RE = re.compile(r"<(https?://[^>]+)>")


def clean_text(text):
    # SlackのGitHub連携等はHTMLエスケープされたmrkdwn記法(<URL|テキスト>)のまま届くため、
    # デコードして「テキスト (URL)」の読みやすい形に変換する。
    # 通知によっては&amp;lt;のように二重にエスケープされていることがあるため2回unescapeする
    text = html.unescape(html.unescape(text))
    text = MRKDWN_LINK_RE.sub(lambda m: f"{m.group(2)} ({m.group(1)})", text)
    text = MRKDWN_BARE_LINK_RE.sub(lambda m: m.group(1), text)
    return text


def format_body(body):
    # Chrome経由の通知本文は「送信元ドメイン\n\n本文」という形になっていることがあるため、
    # ドメイン部分を取り除く。また複数行だとtail -fで見づらいので1行に詰める
    parts = body.split("\n\n", 1)
    content = parts[1] if len(parts) == 2 else body
    content = clean_text(content)
    return " ".join(content.splitlines())


GITHUB_PR_RE = re.compile(r"https://github\.com/([^/\s]+)/([^/\s]+)/pull/(\d+)")


def github_pr_status(text):
    # SlackのGitHub連携通知の本文には「opened by」「merged by」等の状態が含まれていない
    # (Slack上のリッチ表示にしかない)ため、本文中のPR URLからghコマンドで実際の状態を問い合わせる
    match = GITHUB_PR_RE.search(text)
    if not match:
        return None
    owner, repo, number = match.groups()
    try:
        result = subprocess.run(
            ["gh", "pr", "view", number, "--repo", f"{owner}/{repo}", "--json", "state,isDraft"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
        return None
    if data["state"] == "OPEN" and data["isDraft"]:
        return "DRAFT"
    return data["state"]


def on_message(bus, message):
    if message.get_member() != "Notify" or message.get_interface() != "org.freedesktop.Notifications":
        return
    # gnome-shellは受け取った通知を内部で(ヘルパー→shell本体へ)再度Notify呼び出しとして
    # 中継しており、その中継呼び出しも同じmatch条件に引っかかって二重に記録されてしまう。
    # 中継元は「org.freedesktop.Notificationsの現在の所有者」自身なので、そこからの呼び出しは無視する。
    try:
        owner = bus.get_name_owner("org.freedesktop.Notifications")
    except dbus.exceptions.DBusException:
        owner = None
    if owner is not None and message.get_sender() == owner:
        return
    args = message.get_args_list()
    if len(args) < 5:
        return
    app_name, _replaces_id, _icon, summary, body = args[0], args[1], args[2], args[3], args[4]
    actions = args[5] if len(args) > 5 else None
    hints = args[6] if len(args) > 6 else None
    expire_timeout = args[7] if len(args) > 7 else None
    label = classify(app_name, summary, body)

    now = datetime.now()
    with open(DEBUG_LOG_PATH, "a") as f:
        f.write(f"{now}\tapp={app_name!r}\tsummary={summary!r}\tbody={body!r}\tmatched={label}\n")

    if label:
        clean_summary = clean_text(summary)
        clean_body = format_body(body)
        pr_status = github_pr_status(body)
        pr_mark = f"[{pr_status}] " if pr_status else ""
        # SlackのGoogle Calendar連携通知はカテゴリとしては(slack)のままだが、
        # 見た目でカレンダー関連と分かるようアイコンだけは付ける
        is_slack_calendar = label == "slack" and "google calendar" in f"{summary} {body}".lower()
        subcategory = None
        if label == "gmail":
            subcategory = gmail_subcategory(f"{summary} {body}")
            icon = GMAIL_SUBCATEGORY_ICONS.get(subcategory, "")
            if subcategory == "github":
                pr_url = gmail_github_pr_url(body)
                if pr_url:
                    clean_body = f"{clean_body} ({pr_url})"
                    gmail_pr_status = github_pr_status(pr_url)
                    if gmail_pr_status:
                        pr_mark = f"[{gmail_pr_status}] "
        else:
            is_slack_github = label == "slack" and GITHUB_PR_RE.search(body) is not None
            if is_slack_calendar:
                icon = CATEGORY_ICONS.get("calendar", "")
            elif is_slack_github:
                icon = CATEGORY_ICONS.get("github", "")
            else:
                icon = CATEGORY_ICONS.get(label, "")

        # 自分宛(Slackでのメンション、Gmailの個人的な返信メール)は目立たせる
        is_mentioned = MENTION_NAME in body
        is_personal_gmail = label == "gmail" and subcategory in ("github", "other")
        to_me = is_mentioned or is_personal_gmail
        to_me_mark = "🔔 " if to_me else ""

        icon_mark = f"{icon} " if icon else ""
        line = f"[{now:%H:%M:%S}] {icon_mark}{to_me_mark}{pr_mark}({label}) {clean_summary}: {clean_body}"
        if to_me:
            line = f"{ANSI_RED_BOLD}{line}{ANSI_RESET}"
        with open(LOG_PATH, "a") as f:
            f.write(line + "\n\n")

        # ジャンプ機能の見直しに向けて、カレンダー関連通知はactions/hintsも含め全フィールドを別途記録する
        if label == "calendar" or is_slack_calendar:
            with open(CALENDAR_DEBUG_LOG_PATH, "a") as f:
                f.write(
                    f"{now}\tapp={app_name!r}\tsummary={summary!r}\tbody={body!r}\t"
                    f"actions={actions!r}\thints={hints!r}\texpire_timeout={expire_timeout!r}\n"
                )


def main():
    os.makedirs(STATE_DIR, exist_ok=True)
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    bus.add_match_string_non_blocking(
        "eavesdrop=true,type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
    )
    bus.add_message_filter(on_message)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
