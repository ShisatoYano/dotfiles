# Docker関連 チートシート

## シェル関数(`shell/aliases.sh`、要fzf)
| コマンド | 動作 |
|---|---|
| `dc` | `docker compose`の短縮形(`dc up -d`、`dc exec <service> bash`、`dc down`等) |
| `dexec` | 起動中のコンテナをあいまい検索して`bash`で入る |
| `dstop` | 起動中のコンテナをあいまい検索して停止(Tabで複数選択可) |

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
