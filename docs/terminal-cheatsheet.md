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
| `Shift+H` / `Shift+L` | 前/次のタブへ切り替え(nvimの`<S-h>`/`<S-l>`によるバッファ切り替えと同じ覚え方) |
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
| `prs` | 自分に関するPR(自分が出したもの/レビュー依頼が来ているもの)を横断で確認(fzf不要) |

Docker関連(`dc`/`dexec`/`dstop`等)は`docs/docker-cheatsheet.md`(`<leader>dh`)を参照。

## tab-check(bukuのURLを決まったタイミングでタブで開く/アクティブにする)
bukuに特定のタグを付けたURLを、systemdユーザーユニットが決まったタイミングで確認する。
既に開いていればそのタブをアクティブにするだけ(ウィンドウのフォーカスは奪わない)、開いていなければ新規タブで開く。
`~/dotfiles/scripts/tab-check.sh <bukuタグ名>`が本体で、タグ・スケジュールごとにsystemdユニットを分けている。

| タグ | 実行タイミング(平日) |
|---|---|
| `notion_check` | ログイン時・13時・16時 |
| `attendance_check` | ログイン時・19時 |
| `slack_check` | ログイン時 |
| `schedule_check` | ログイン時・13時・16時 |
| `mail_check` | ログイン時 |

「ログイン時」は`login-tab-check.service`(`graphical-session.target`にひもづけ、平日のみ`ExecCondition`で判定)が担当。
`OnCalendar`+`Persistent=true`のタイマーは1日1回しか追いつき実行しない(PCが起動したまま日付をまたぐと、その日は二度と追いつかない)ため、
「毎ログインで実行したい」用途にはtimerではなく`graphical-session.target`への直接フックを使う。

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

## Claude Code
| キー | 動作 |
|---|---|
| `Ctrl+O` | トランスクリプトビューアーを開閉(過去の出力をフルスクリーンで遡れる、`j`/`k`でスクロール) |
| `{` / `}` | トランスクリプトビューアー内でプロンプト単位にジャンプ |
| `?` | トランスクリプトビューアー内のショートカット一覧 |
