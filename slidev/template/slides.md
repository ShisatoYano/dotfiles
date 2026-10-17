---
theme: default
title: __TITLE__
# 日本語がGoogle Fonts側の欧文フォントにフォールバックして崩れないよう、和文フォントを明示する
# (初回のみGoogle Fontsから取得。オフラインで作るときは local: を使うか、この項目ごと消す)
fonts:
  sans: Noto Sans JP
  serif: Noto Serif JP
  mono: JetBrains Mono
  weights: '400,700,900'
# ~/slides/addons の自作部品。Slidevはデッキのフォルダの「親」を起点に解決するため、../ は2つで ~/slides に届く
addons:
  - ../../addons/slidev-addon-yano
transition: slide-left
mdc: true
layout: cover
hideInToc: true
# 記法の早見表は ~/dotfiles/docs/slidev-cheatsheet.md(nvimなら <leader>sh)
# 構成のルールと部品の見本は ~/slides/CLAUDE.md と ~/slides/decks/public/showcase/
---

# __TITLE__

__DATE__ / Shisato Yano

---

## 自己紹介

- Shisato Yano

<Callout label="今日のゴール" class="mt-10">
  この発表で持ち帰ってほしいことを1文で
</Callout>

<!-- ここはプレゼンターノート(発表者ビューにだけ出る) -->

<!--
15分以上の発表では、ここに目次を置き、本編を章ごとに分ける。

## 目次

<Toc maxDepth="1" />

---
src: ./pages/01-xxx.md
---

pages/01-xxx.md の先頭は layout: section の章扉(# 見出し)にし、通常のスライドは ## 見出しにする。
-->

---

## 課題

- 聴衆が抱えている困りごと

<KeyMessage v-click>このスライドの結論を一文で</KeyMessage>

---

## 解決

- 提案するやり方と、なぜそのやり方なのか

---

## 実例

- コマンドやコード、デモ

---

## まとめ

- 冒頭の「今日のゴール」を回収する

---
layout: center
class: text-center
---

# ご清聴ありがとうございました

試してほしいコマンド・リポジトリへのリンクなど、持ち帰れるものを置く
