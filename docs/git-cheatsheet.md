# Git関連 チートシート

## gitsigns(コード編集中の変更管理)
| キー | 動作 |
|---|---|
| `]c` / `[c` | 次/前の変更箇所へジャンプ |
| `<leader>hp` | 変更内容をプレビュー |
| `<leader>hr` | その変更箇所を元に戻す |
| `<leader>hR` | ファイル全体の変更を元に戻す |
| `<leader>hs` / `<leader>hu` | その変更箇所をステージ/アンステージ |
| `<leader>hb` | 行末blame表示のON/OFF |

## vim-flog(コミットグラフ、`<leader>gl`で起動)
| キー | 動作 |
|---|---|
| `j` / `k` | コミット間を移動(右の差分も連動) |
| `gq` | 閉じる |
| `cc` | チェックアウト |
| `crc` | revert |
| `ca` | amend |
| `?` | flog専用ヘルプ |

## lazygit(`<leader>gg`で起動)
| キー | 動作 |
|---|---|
| `Space` | ステージ/アンステージ |
| `c` | コミット |
| `Ctrl+g` | git-czで規約付きコミット |
| `P` / `p` | push / pull |
| `?` | lazygit専用ヘルプ |

## gh(GitHub CLI)

### Issue
| コマンド | 動作 |
|---|---|
| `gh issue list` | Issue一覧 |
| `gh issue create` | Issue作成(対話形式) |
| `gh issue view 番号 --web` | ブラウザで開く |

### PR
| コマンド | 動作 |
|---|---|
| `gh pr create` | PR作成 |
| `gh pr list` | PR一覧 |
| `gh pr status` | 自分に関連するPRの状況を一覧(レビュー待ち・自分が出したPR等) |
| `gh pr view 番号 --web` | ブラウザで開く |
| `gh pr checkout 番号` | ローカルにそのブランチを取得 |
| `gh pr diff 番号` | 差分をターミナルで確認 |
| `gh pr checks` | CI/CDのチェック状況を確認 |
| `gh pr merge 番号` | マージ(squash/rebase等を対話形式で選択) |
| `gh pr checkout 番号` | レビュー対象のブランチを取得 |
| `gh pr review 番号 --approve` | 承認 |
| `gh pr review 番号 --request-changes --body "..."` | 変更要求 |
| `gh pr review 番号 --comment --body "..."` | コメントのみ |
| `gh pr view 番号 --web` | ブラウザで開く(行単位コメントはこちらが必要) |

### リポジトリ
| コマンド | 動作 |
|---|---|
| `gh repo view --web` | 今いるリポジトリをブラウザで開く |
| `gh repo clone 組織名/リポジトリ名` | クローン(単発ならこちら、通常はghq推奨) |
| `gh browse` | 今いるリポジトリのGitHubページをブラウザで開く |
| `gh browse ファイル名` | 特定ファイルのGitHub上のページを開く |

## ghq(リポジトリ管理)
| コマンド | 動作 |
|---|---|
| `ghq get <URL>` | リポジトリをクローン |
| `ghq list` | 管理下のリポジトリ一覧 |
| `ghq list -p` | フルパス付きで一覧 |
| `cd $(ghq list -p \| fzf)` / `gcd` | あいまい検索してリポジトリへ移動(要fzf) |

## gibo(.gitignore生成)
| コマンド | 動作 |
|---|---|
| `gibo dump macOS >> .gitignore` | 指定テンプレートを`.gitignore`に追記 |
| `gibo list` | 利用可能なテンプレート一覧 |
| `gibo dump $(gibo list \| fzf) >> .gitignore` | fzfでテンプレートを選んで追記 |
