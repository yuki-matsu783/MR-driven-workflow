---
title: worklog: 【調査】テンプレート二重管理と統括レポートとの役割分担
type: log
description: issue #145 フェーズ2（調査）の試行錯誤ログ（push1）
tags: [worklog, issue-mr-flow, template]
keywords: [調査, 二重管理, describe, 統括レポート, dist-layers, 非対話セッション]
---

# worklog: 【調査】テンプレート二重管理と統括レポートとの役割分担

対象: MR/PRテンプレートをアーカイブとして再設計する（2026-08-23）。
全体作業計画: `plans/mellow-archiving-lantern.md`
個別作業計画: `plans/【調査】テンプレート二重管理と統括レポートとの役割分担.md`
push回数: 1

## 試したこと

- `get_vcs_access_mode` を実行し、この実行環境が `mcp` 経路であることを確認した
  （`gh`/`glab` CLIが無い。`references/mcp-fallback.md` の読み替えに従う）。
- Draft PRの作成: ブランチがbaseと完全に同一（ahead 0 / behind 0）だったため、
  `mcp__github__create_pull_request` をそのまま呼ぶと「No commits between」で失敗する状態だった。
  `add_empty_commit_for_draft_mr` で空コミットを1つ積んでからPRを作成し、PR #187 を得た。
- HTMLビューの生成手順: テンプレートの `<!DOCTYPE html>` 〜 `</head>` を `sed -n` で切り出し、
  `<title>` だけを差し替えてから本文をヒアドキュメントで追記する形にした。スクラッチパッドへ
  `mkhtml.sh` として置き、後続の計画・レポートでも使い回す。

## うまくいったこと

- 上記の `mkhtml.sh` により、テンプレートの `<style>` を1バイトも触らずにHTMLビューを作れる
  （自己完結性・ダークモード対応がテンプレートのまま保たれる）。
- 生成後の検査を3本（プレースホルダ残存・`src`/`href` の外部参照・`url()`/`@import` の外部参照）
  そのまま実行できる形にした。いずれも0件を確認。

## ダメだったこと

- `mkhtml.sh` の初版で `printf '\-\->\n'` と書いたところ、bashの `printf` が `-->` を
  **オプションとして解釈**して `printf: --: invalid option` で失敗した。
  `printf '%s\n' '-->'` へ書き換えて解消した。
  （`.claude/rules/shell-script-style.md`「JSON操作」が `jq --args` / `grep` について書いている
  「ハイフンで始まる値」の問題と同根。**`printf` でも同じことが起きる**。）

## 敵対的レビュー（フェーズ2・1回目）

対象: `plans/` の全体作業計画・個別調査計画とそれぞれのHTMLビュー（4ファイル）。
実施回数カウンタ: 1/3（`adversarial-review-count.sh increment 2`）。

findings 10件。1次振り分け（確度×重大度）で **major/high 6件が投稿候補**、
**minor/medium 4件は「報告」**（この表の medium×minor は投稿対象外）。
投稿候補6件を `select-adversarial-findings.sh` へ渡した結果は `posted=6 / reported=0`
（層追加のしきい値10・ハードシーリング20のいずれにも達していない）。

### 投稿した6件（すべて major / 確度 high）

| # | 対象 | 指摘 | 対応 |
|---|---|---|---|
| 1 | 全体作業計画 | 見出し構成を3行に固定している既存テスト `test_install_to_project.sh` が変更対象に無い | 変更対象表へ追加し、期待値の更新方針（固定値 `3` をやめ見出しの集合で比較）を方針節へ明記 |
| 2 | 全体作業計画 | 検証の見出し比較が変更前から通る（空振り） | 検証節を表形式へ差し替え、**変更前の実測結果**を併記。期待値を書き下した比較へ変更 |
| 3 | 全体作業計画 | `generate-ddr-list.sh` を素で呼んでも一致検証にならない | `--check` へ変更。`extract-frontmatter.sh` は検証から外し、その理由を明記 |
| 4 | 全体作業計画 | `distribution-assets.md` が旧3節構成を仕様として固定している衝突が計画に無い | 変更対象表へ追加し、現行の2規定をどう書き換えるかを表で明記 |
| 5 | 個別調査計画 | 「3箇所」は数え漏れ（`index.md` と `distribution-assets.md` がある） | 5箇所の表へ差し替え、`.gemini/` を数えない理由・`directory-structure.md` が影響しない判定も明記 |
| 6 | 全体作業計画HTML | md側の「フェーズ3〈作業〉」節がHTMLに無い | HTMLへ `#phase-impl` セクションと目次項目を追加 |

### 報告のみに留めた4件（minor / 確度 medium）

MRへは出していないが、**内容としては妥当だったため4件とも計画へ反映した**。

| # | 対象 | 指摘 | 対応 |
|---|---|---|---|
| 7 | 全体作業計画 | 「ルール側はフェーズ4でも可」が両論併記で、フェーズ4の見込みリストと食い違う | フェーズ3へ確定（`docs-workflow.md` は主たる成果物側なので `【AIアセット作成】`） |
| 8 | 全体作業計画 | 合意状況（flow-id 1-5 未実施）が書かれていない | 冒頭へ合意状況の段落を追加。HTML側も警告ボックスで明示 |
| 9 | 全体作業計画 | 10節構成の見出し名がどこにも列挙されていない | 「新しい見出し構成」節を新設し、順序込みで転記（以後これを計画内の正とする） |
| 10 | 個別調査計画 | AI作成のPRにはテンプレートが適用されない点が問1の前提に無い | 初期本文が `Github.sh` / `Gitlab.sh` / `mcp-fallback.md` にハードコードされている事実を問1へ追加 |

### 検証コマンドの変更前実測（指摘2・3への対応）

```
bash .claude/scripts/test/test_install_to_project.sh   → passed=98 failures=0
bash .claude/scripts/src/generate-ddr-list.sh --check  → DDR一覧は最新です（85件）／exit=0
bash .claude/scripts/src/check-doc-references.sh       → 参照切れ数=0
```

見出しの `diff` は**変更前のツリーで終了コード0**（＝空振り）だったため、検証から外した。

### 「実装状況」を列挙している箇所の数え切り（指摘5への対応）

```
.github/pull_request_template.md:19
.gitlab/merge_request_templates/Default.md:22
index.md:52
.claude/skills/issue-mr-flow/references/review-loop.md:144
.claude/docs/spec/distribution-assets.md:33
```

ほかに `.claude/docs/ddr/i0050-01-….md:55` が地の文で「現在の計画・実装状況」と述べているが、
**見出し構成の列挙ではなく、DDR本文は変更しない運用**のため対象外とした。


## 次の一歩

- flow-id 2-4: 投稿した6スレッドへ返信し、`set-header --unreplied 0` を記録する。
- flow-id 2-5: `describe` でMR descriptionを更新する（この時点ではまだ旧テンプレート構成で書く）。
- flow-id 2-6: 調査を実施し `reports/` へ結果を書く。
