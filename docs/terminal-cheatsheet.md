# ターミナル環境 チートシート

WezTermのキーバインド、シェル関数、Claude Code操作など、nvimの外側(ターミナル環境)で使うものをまとめたもの。

## WezTerm(leaderキー: `Ctrl+a`、1秒以内に次のキー)
| キー | 動作 |
|---|---|
| `v` | ペインを左右に分割 |
| `s` | ペインを上下に分割 |
| `h` / `j` / `k` / `l` | ペイン移動(leader無しの`Ctrl+h/j/k/l`でも移動可能。nvim起動中はそちらがnvimのウィンドウ移動と統合される) |
| `x` | 現在のペインを閉じる(確認あり) |
| `c` | コピーモードに入る |
| `u` / `d` | スクロールバックを1ページ分 上/下 |
| `←` / `→` / `↑` / `↓` | ペインサイズをその方向に2セルずつ調整 |
| `t` | ライト/ダーク配色を切り替え |
| `,` | 現在のタブ名を手動リネーム(空にするとリセット) |
| `g` | タブ一覧から選んで切り替え(プロジェクト名付き) |
| `q` | WezTermを終了 |

その他のショートカット:
| キー | 動作 |
|---|---|
| `Shift+PageUp` / `Shift+PageDown` | スクロールバック(標準機能、Fnキー併用が必要な場合あり) |

## シェル関数(`shell/aliases.sh`、要fzf)
| コマンド | 動作 |
|---|---|
| `gcd` | ghq管理下のリポジトリをあいまい検索して移動 |
| `bb` | bukuのブックマークをあいまい検索してブラウザで開く(Tabで複数選択可) |
| `ta` | 開いているタブをあいまい検索して切り替え(tabctl) |
| `tc` | 開いているタブをあいまい検索して閉じる(Tabで複数選択可) |
| `tabarchive` | 選んだタブをbukuに保存してから閉じる(Tabで複数選択可、既存URLは保存をスキップ) |
| `tabarchive-all` | 開いている全タブをbukuに保存してから閉じる |
| `ff [ディレクトリ]` | 指定ディレクトリ以下(省略時はカレント)のファイルをあいまい検索し、パスを出力 |
| `dc` | `docker compose`の短縮形(`dc up -d`、`dc exec <service> bash`等) |
| `dexec` | 起動中のコンテナをあいまい検索して`bash`で入る |
| `dstop` | 起動中のコンテナをあいまい検索して停止(Tabで複数選択可) |
| `prs` | 自分に関するPR(自分が出したもの/レビュー依頼が来ているもの)を横断で確認(fzf不要) |

## tab-check(bukuのURLを定期的にタブで開く/アクティブにする)
bukuに特定のタグを付けたURLを、systemdユーザータイマーが決まった時間に確認する。
既に開いていればそのタブをアクティブにするだけ(ウィンドウのフォーカスは奪わない)、開いていなければ新規タブで開く。
電源が入っていなかった回は次回起動時に1回だけ追いつく(`Persistent=true`)。
`~/dotfiles/scripts/tab-check.sh <bukuタグ名>`が本体で、タグ・スケジュールごとにsystemdユニットを分けている。

| タグ | 実行タイミング(平日) |
|---|---|
| `notion_check` | 10時・13時・16時 |
| `attendance_check` | 10時・19時 |
| `slack_check` | 10時 |
| `schedule_check` | 10時・13時・16時 |

| コマンド | 動作 |
|---|---|
| `buku --nostdin -u <番号> --tag + <タグ名>` | 既存ブックマークに対象タグを追加 |
| `~/dotfiles/scripts/tab-check.sh <タグ名>` | 手動実行(動作確認用) |
| `systemctl --user list-timers` | 各タイマーの次回実行予定を確認 |
| `systemctl --user status notion-check.timer` 等 | 有効化状態を確認 |
| `journalctl --user -u notion-check.service` 等 | 実行結果・エラーを確認 |

catch-up実行(電源オフ中に逃した回の追いつき)はセッションPATHが未反映な場合があるため、
各`.service`で`Environment=PATH=...`を明示指定している。またWezTerm/Chromeは
`~/.config/autostart/`(dotfilesの`autostart/`配下)でログイン時に自動起動する設定にしており、
catch-up実行時にChromeが起動済みである可能性を上げている。

## notify-relay(Slack/Calendar/Gmailの通知をログに記録する常駐サービス)
GNOME通知のポップアップは「設定 > 通知」でアプリ(Google Chrome)ごとにオフにする想定。
ポップアップを止めても内容を見逃さないよう、D-Bus上を流れる通知(`org.freedesktop.Notifications.Notify`)を
gnome-shellの処理を横取りせず観測(eavesdrop)し、Slack/Calendar/Gmailに該当するものだけログへ書き出す。
Chrome経由の通知は`app_name`が常に"Google Chrome"になり判別に使えないため、
本文に含まれる送信元ドメイン(`app.slack.com`/`mail.google.com`/`calendar.google.com`等)や
キーワードで判定している(`~/dotfiles/scripts/notify-relay.py`の`KEYWORDS`)。

- 本文に`MENTION_NAME`(`@Shisato Yano`)が含まれる場合は`🔔MENTION`を先頭に付ける
- 本文にGitHubのPR URLが含まれる場合、Slackの通知本文自体には opened/merged の情報が
  含まれていないため、`gh pr view`でPRの実際の状態(OPEN/MERGED/CLOSED/DRAFT)を問い合わせて
  `[MERGED]`のように付与する
- Slackはブラウザ版(Chrome)・ネイティブアプリのどちらの通知でも同様に拾う(ソースは区別しない)
- Slackはネイティブアプリ経由(`app_name`が`Slack`)の通知だけを拾い、ブラウザ版(`Google Chrome`)は
  同じ内容が重複するため無視する(`classify()`内で`is_chrome`判定)

| コマンド | 動作 |
|---|---|
| `tail -f ~/.local/state/notify-relay/notify.log` | 該当した通知をリアルタイムに表示 |
| `tail -f ~/.local/state/notify-relay/debug.log` | 判定結果に関わらず全通知の生データを表示(キーワード調整用) |
| `systemctl --user status notify-relay.service` | 常駐状態を確認 |
| `systemctl --user restart notify-relay.service` | `KEYWORDS`変更後などに再起動して反映 |

## Claude Code
| キー | 動作 |
|---|---|
| `Ctrl+O` | トランスクリプトビューアーを開閉(過去の出力をフルスクリーンで遡れる、`j`/`k`でスクロール) |
| `{` / `}` | トランスクリプトビューアー内でプロンプト単位にジャンプ |
| `?` | トランスクリプトビューアー内のショートカット一覧 |
