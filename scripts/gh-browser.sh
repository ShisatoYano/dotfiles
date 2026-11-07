#!/usr/bin/env bash
# GH_BROWSERに指定し、gh dash等でブラウザを開く際のChrome/xdg-openのログ出力を捨てる。
# 未指定だとgo-ghが出力を端末へ直接流し、gh dashのTUI表示が崩れる。
# 出力をパイプのまま残すと起動したChromeが握り続け、gh dash側の「Opening in browser」が終わらないためexecで差し替える
exec xdg-open "$@" >/dev/null 2>&1
