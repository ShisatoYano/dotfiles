---
theme: default
title: __TITLE__
# 日本語がGoogle Fonts側の欧文フォントにフォールバックして崩れないよう、和文フォントを明示する
# (初回のみGoogle Fontsから取得。オフラインで作るときは local: を使うか、この項目ごと消す)
fonts:
  sans: Noto Sans JP
  serif: Noto Serif JP
  mono: JetBrains Mono
transition: slide-left
mdc: true
# 記法の早見表は ~/dotfiles/docs/slidev-cheatsheet.md(nvimなら <leader>sh)
---

# __TITLE__

__DATE__ / Shisato Yano

---

## 目次

1. 背景
2. 本題
3. まとめ

---

## 背景

- ここに内容を書く

<!-- ここはプレゼンターノート(発表者ビューにだけ出る) -->

---
layout: two-cols
---

## 左

- 箇条書き

::right::

## 右

- 図やコードを置く

---
layout: center
class: text-center
---

# まとめ

ご清聴ありがとうございました
