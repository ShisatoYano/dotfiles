# Slidev(発表資料) チートシート

Markdownで書いてブラウザで発表するスライドツール。資料は`~/slides/decks/<日付>-<スラッグ>/slides.md`に置く。

`~/slides`の`package.json`と`node_modules`は`dotfiles/slidev`へのシンボリックリンクで、
Slidev本体・テーマ・playwright(書き出し用)はここに1セットだけ入っている。デッキを増やしても`npm install`は要らない。

## シェル関数(`shell/aliases.sh`、要fzf)
| コマンド | 動作 |
|---|---|
| `slidenew <タイトル>` | `~/slides/decks/<日付>-<スラッグ>/slides.md`をテンプレートから作ってnvimで開く |
| `slidedev` | デッキをあいまい検索して開発サーバを起動(ブラウザが開き、保存のたび反映される) |
| `slideexport` | デッキと形式(pdf/pptx/png)を選んで書き出し。出力先はデッキのフォルダ内 |

自分でコマンドを叩くときは、**必ず`~/slides`をカレントにする**(依存の解決がこのディレクトリで通るため)。

```bash
cd ~/slides
npx slidev decks/2026-09-21-ekf/slides.md --open        # 開発サーバ
npx slidev export decks/2026-09-21-ekf/slides.md \
  --format pdf --with-clicks --output decks/2026-09-21-ekf/ekf.pdf
```

`--with-clicks`を付けるとクリックアニメーションの各段階を別ページとして書き出す。`--range 1,3-5`でページを絞れる。

## 発表中の操作(ブラウザ)
| キー | 動作 |
|---|---|
| `→` / `space` | 次(クリックアニメーション単位) |
| `←` | 前 |
| `↑` / `↓` | スライド単位で移動(アニメーションを飛ばす) |
| `f` | フルスクリーン |
| `o` | スライド一覧(オーバービュー) |
| `d` | ダーク/ライト切り替え |
| `g` | ページ番号を入力してジャンプ |

発表者ビューはURL末尾に`/presenter`(ノート・次スライド・経過時間)。`/overview`で全体一覧。

> **Vimiumとの衝突に注意**: `f`/`o`/`d`/`g`はVimiumのリンクヒント・Vomnibar・半ページスクロール・`gg`の前置キーと
> 衝突し、そのままではSlidevに届かない。`vimium/excluded-urls.txt`の内容をVimiumの
> 「Excluded URLs and keys」に登録して`localhost`でこの4キーを譲ること(`docs/vimium-cheatsheet.md`参照)。
> 未設定のまま使うなら、左下にホバーで出るUIボタン(全画面・一覧・ダーク・発表者モード)で代替できる。

## 基本の記法
スライドの区切りは空行を挟んだ`---`。先頭ブロックが全体設定(headmatter)、2枚目以降の`---`直後に書けばそのスライドだけの設定になる。

```md
---
theme: default      # テーマ
fonts:              # 和文が欧文フォントにフォールバックしないよう明示する
  sans: Noto Sans JP
mdc: true           # Markdown内でクラス指定を使えるようにする
---

# タイトル

---
layout: two-cols    # このスライドだけのレイアウト
---
```

| レイアウト | 用途 |
|---|---|
| `cover` | 表紙 |
| `center` | 中央寄せ(章の区切りやまとめ) |
| `two-cols` | 左右2カラム。`::right::`で右カラムに切り替え |
| `image-right` / `image-left` | 片側に画像(`image: ./images/foo.png`を併記) |
| `full` | 余白なしで全面に使う |

`<!-- コメント -->`はプレゼンターノートとして発表者ビューだけに出る。

## アニメーション
| 記法 | 動作 |
|---|---|
| `<v-click>...</v-click>` | クリックで表示 |
| `<v-clicks>`で箇条書きを囲む | 項目を1つずつ表示 |
| `<v-click at="3">` | 3クリック目で表示 |
| `<v-after>` | 直前の要素と同時に表示 |

## コード
````md
```python {2,4}         # 2行目と4行目をハイライト
```python {1|2|3}       # クリックごとにハイライト行を移す
```python {*}{maxHeight:'400px'}  # 長いコードはスクロール
````

## 数式・図
| 記法 | 動作 |
|---|---|
| `$x_k$` / `$$...$$` | KaTeXによる数式(インライン/ブロック) |
| ` ```mermaid {scale: 0.8} ` | Mermaid図(日本語ラベルも可) |
| ` ```plantuml ` | PlantUML図(公式の公開サーバで描画するのでネット接続が要る) |
| `![説明](./images/foo.png)` | 画像。デッキのフォルダからの相対パス |
| `<img src="./images/foo.png" class="w-80">` | サイズを指定したいときはHTMLで書く |

レイアウト微調整にはUnoCSSのユーティリティクラスがそのまま使える(`class="text-sm opacity-70"`、`<div class="grid grid-cols-2 gap-4">`など)。

## 注意
- フォント(Noto Sans JP等)は初回ビルド時にGoogle Fontsから取得する。オフラインで作業するならheadmatterの`fonts:`を消すか`local:`指定にする
- **依存を足すときは`~/dotfiles/slidev`で`npm install <パッケージ>`する**。`~/slides`側で実行すると、リンクしてある`package.json`が実ファイルに置き換わってdotfilesの管理から外れる
- テーマを変えたい場合は、`dotfiles/slidev/package.json`にテーマを足してからheadmatterの`theme:`を書き換える
