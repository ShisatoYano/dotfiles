# Docker関連 チートシート

## シェル関数(`shell/aliases.sh`、要fzf)
| コマンド | 動作 |
|---|---|
| `dc` | `docker compose`の短縮形(`dc up -d`、`dc exec <service> bash`、`dc down`等) |
| `dexec` | 起動中のコンテナをあいまい検索して`bash`で入る |
| `dstop` | 起動中のコンテナをあいまい検索して停止(Tabで複数選択可) |

## lazydocker(WezTermで`Leader+Shift+D`、またはコマンドで`lazydocker`)
コンテナの起動停止・ログ・リソース使用状況・シェル接続をTUIでまとめて操作する。
`docker-compose.yml`のあるディレクトリで起動すると、そのプロジェクトのサービスが一覧に出る
(WezTermのキーは今いるペインのディレクトリで起動する)。

| キー | 動作 |
|---|---|
| `1`〜`6` | パネル移動(プロジェクト/サービス/コンテナ/イメージ/ボリューム/ネットワーク) |
| `[` / `]` | 右側のタブ切り替え(ログ/stats/環境変数/config等) |
| `U` / `D` | プロジェクト全体を`up`/`down`(サービスパネル) |
| `u` / `s` / `r` | 選択したサービスを起動/停止/再起動 |
| `R` | 再起動オプション(リビルドして再作成など) |
| `E` | 選択したコンテナのシェルに入る(`dexec`相当) |
| `m` | ログを表示 |
| `b` | 一括操作(停止中コンテナや未使用イメージの一括削除など) |
| `/` | 一覧の絞り込み |
| `q` | 終了 |

**注意(v0.25.2時点のlazydockerの不具合)**: ディレクトリ名に大文字を含むプロジェクト(例: `AutonomousVehicleControlBeginnersGuide`)では、
コンテナが1つも無い状態で`u`/`U`すると`invalid project name`エラーになる(ディレクトリ名を小文字化せずに`-p`へ渡すため)。
初回だけシェルで`dc up -d`してコンテナを作れば以降はlazydockerから操作できる。停止は`s`を使い、コンテナを消す`D`は避ける。

## GUIアプリ(matplotlib等)をコンテナから表示する
`docker-compose.yml`で`DISPLAY`環境変数と`/tmp/.X11-unix`を渡していても、
ホストのX serverへの接続許可(認証)が別途必要。許可が無いと
`Authorization required, but no authorization protocol specified`エラーになる。

`xhost +local:docker`でローカルのDocker接続を許可する。この設定はログインセッションごとに
リセットされるため、`~/.config/autostart/xhost-docker.desktop`(dotfilesの`autostart/`配下)で
ログイン時に自動実行するようにしている。

## devcontainer(VSCode向け)をVSCode無しで使う
`.devcontainer/devcontainer.json`が`dockerComposeFile`を参照しているだけの構成であれば、
VSCodeの拡張機能無しでも同じ`docker-compose.yml`をそのままCLIから使える。

- **編集**: `docker-compose.yml`が通常カレントディレクトリをコンテナにそのままマウントしているため、
  ホスト側でnvimで直接編集すればよく、コンテナに入る必要はない
- **実行**: コンテナ固有の言語バージョンや依存パッケージが必要な処理(実行・テスト等)だけ、
  `dc exec <service> bash`のようにコンテナに入って行う

## 設定変更後、コンテナのリビルドが必要か
| 変更したもの | 必要な操作 |
|---|---|
| `requirements.txt`、`Dockerfile` | リビルドが必要(`dc up -d --build`または`dc build`) |
| `docker-compose.yml`の`volumes`/`environment`等(`build:`のcontext以外) | `dc up -d`で再作成すれば反映(リビルド不要) |
| `devcontainer.json`のVSCode設定・拡張機能、`pyrightconfig.json`等 | 何も操作不要(エディタ側だけが読む設定で、コンテナの実行内容とは無関係) |
