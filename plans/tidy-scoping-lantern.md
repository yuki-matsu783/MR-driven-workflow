---
title: 計画・レポートの人間レビュー用HTMLビューをテンプレートへ切り出す（全体作業計画）
type: plan
description: issue #54の全体作業計画。plans/reportsの人間レビュー用HTMLビューの型をassets/配下のテンプレート2本へ切り出し、SKILL.md・rulesの参照を整える。
tags: [issue-mr-flow, plan, template, html]
keywords: [issue54, assets, plans.template.html, reports.template.html, canvas-report, 改名, docs-workflow, flow-id, 敵対的レビュー]
---

# 全体作業計画: 計画・レポートの人間レビュー用HTMLビューをテンプレートファイルへ切り出す（issue #54）

- issue: #54 <https://github.com/yuki-matsu783/MR-driven-workflow/issues/54>
- PR: #156 <https://github.com/yuki-matsu783/MR-driven-workflow/pull/156>
- ブランチ: `claude/plan-report-html-template-024l0t`

## このissueの狙い（issue本文の要約）

計画（`plans/`）・レポート（`reports/`）の**人間がレビューするためのHTMLビュー**の型を、
`.claude/skills/issue-mr-flow/assets/` 配下のテンプレートファイル2本へ切り出す。狙いは
(1) 導入先プロジェクトの拡張点の分離、(2) レビュアーの認知負荷の低減、(3) 体裁の揺れと生成
コストの削減の3点。**markdownのテンプレートは作らない**（md側の見出し構成は引き続き自由記述）。

## 進め方の全体像

| フェーズ | 何をするか | 主な成果物 |
|---|---|---|
| 1〈起点〉 | issue取得・Draft PR作成・本計画・HANDOFF.md | 本ファイル / PR #156 |
| 2〈調査〉 | 下記「フェーズ2でやること」 | `reports/…調査.md` ＋ `.html` |
| 3〈作業〉 | テンプレート2本の作成と、SKILL.md・rules・canvas-report改名 | `assets/*.template.html` ほか |
| 4〈反映〉 | 下記「フェーズ4でやること」 | `.claude/docs/spec/` `ddr/` ほか |
| 5〈クローズ〉 | コンフリクト検知・関連issue通知・統括レポート・片付け・Draft解除 | 統括レポート |

## フェーズ2〈調査〉でやること

このissueは「テンプレートを新設する」だけに見えるが、**issue本文が前提としている事実のうち、
その後の変更で動いた可能性があるもの**が複数ある。実装前に確定させる。

1. **HTMLの外部依存方式**（最重要）。issue本文は「TailwindCSS CDN方式」を前提にしているが、
   その後 DDR `i0141-01` が canvas 形式について Tailwind CDN 依存をやめている。同DDRは
   「`reports/` 配下の通常の一覧・表形式HTMLは引き続きTailwindCSS CDN方式」と限定を置いて
   いるため、**新設テンプレートをどちらにするかは判断が要る**。**判断の主根拠はCDNへの到達性
   ではない**（到達不可は `i0141-01` が既知としたうえで `reports/` をCDNに据え置いている）。
   判断軸と決定規則は個別調査計画「Q1の決定規則」に置く。
2. **既存の実物**（`reports/*.html` の履歴上の実例）の構成を可能な範囲で確認し、必須／任意
   セクションの候補を得る。
3. **flow-idのずれ**。issue本文は片付けを flow-id 5-1 と書くが、現行SKILL.mdでは 5-4 である
   （issue #112・#111 の並べ替え）。本文中の flow-id をすべて現行番号へ読み替える。
4. **`plans/` のHTMLビューのファイル名規則**（issue本文が「実装時に確定する」としている点）。
   `plans/` の md は全体作業計画（自動命名）と個別計画（`【種別】〜`）で命名体系が違うため、
   両者に一意に対応する規則を決める。
5. **参照箇所の全数洗い出し**。`templates/` の文字列参照、`reports/*.html` の作成手順が
   書かれている箇所（SKILL.md・rules・canvas-report/SKILL.md・spec）を漏れなく列挙する。
   **一覧は「改訂する箇所」と「ヒットするが改訂しない箇所」（DDR本文・specの過去changelog）の
   2列に分ける。**
6. **`assets` という語の既存用法との衝突**。`apply-mr-workflow-to-project` が `assets/` を
   配布アセットの集約先（`.gitignore` 対象のビルド用一時ディレクトリ）として既に使っている。
   語彙を `assets/` へ寄せる判断の材料を集める。
7. **`cleanup-task.sh` が `plans/*.html` を削除するかどうか**の確認（受け入れ条件）。
8. **`extract-frontmatter.sh` / `index.jsonl` が `.html` を拾うかどうか**の確認
   （`plans/*.html` のfrontmatterの扱いをどう書くかの根拠）。

## フェーズ3〈作業〉でやること

- `.claude/skills/issue-mr-flow/assets/plans.template.html` の新設。
- `.claude/skills/issue-mr-flow/assets/reports.template.html` の新設。
- `.claude/skills/canvas-report/templates/` → `assets/` の `git mv` と参照更新（2箇所）。
- `.claude/skills/issue-mr-flow/SKILL.md` の改訂
  （全体フロー表・`start` 手順3・flow-id 1-4/2-1/3-1/4-1/2-6/3-6/4-6 へのテンプレート参照）。
- `.claude/rules/docs-workflow.md`（ライフサイクル表に `plans/*.html` の行）・
  `.claude/rules/directory-structure.md`（ツリー・配置の指針）・
  `.claude/rules/markdown-frontmatter.md`（`plans/*.html` は対象外）の改訂。

種別は `【AIアセット作成】`（テンプレートとスキル定義そのものが主たる成果物であるため）を用い、
テンプレート本体と、それを参照するAIアセット群の改訂を1つの計画で扱うか分けるかは flow-id 3-1
で決める。

## フェーズ4〈反映〉でやること

反映対象は flow-id 4-1 で洗い出す。現時点の見込み（確定ではない）は次のとおり。

- `.claude/docs/spec/` — 新設テンプレートの仕様（置き場所・必須／任意セクション・
  プレースホルダ方式・作成タイミング）を記す先。既存 `issue-mr-workflow.md` へ追記するか
  新規specを起こすかは 4-1 で判断する。
- `.claude/docs/ddr/` — 「`assets/` を語彙として採る」「HTMLの外部依存方式」「`plans/` にも
  HTMLビューを置く」の3点は、いずれも却下案のある意思決定であり DDR 候補。
- AIアセット反映 — 作業中に気づいたルール・スキルの不備。

## やらないこと（スコープ外）

- markdownテンプレートの新設（issue本文が明示的に除外）。
- 最終統括レポート用のテンプレート（issue本文が明示的に除外。flow-id 5-3 の統括レポートは
  本issueのテンプレート土台の対象外）。
- `HANDOFF.md` のテンプレート外だし（issue #28 のマージ前通知で提起された論点。
  `cleanup-task.sh` へ埋め込む決定＝**DDR `i0028-01`**「flow-id 5-1の後片付けはスクリプト化し
  コミットは含めない」の却下案(b)。フェーズ2のQ8で突き合わせ、覆すか否かを結論として記録する。
  覆すべきという結論になった場合は本issueでは扱わず、別issueの起票を提案する）。
- `.mrworkflow.json` への設定項目追加（issue本文が明示的に除外）。

## 本issueは分割しない

「期待する動作」は `plans.template.html` と `reports.template.html` の2つを並べているが、
同型の成果物の並列列挙ではない。両者は共通のヘッダ帯・スタイルを持ち見た目を揃える要件が
あり、片方だけマージすると SKILL.md の記述と rules のライフサイクル表が中途半端な状態で
main に載る。`canvas-report/templates/` の改名も、語彙の並立を避けるという目的上、
テンプレート新設と同時にmainへ入る必要がある。よって1つのissueとして進める。

**この判断はAIの提案段階に留まる**（分割の判断は提案までがAIの役割で、決めるのは人間である。
`plans/REVIEW-POINTS.md`「issue分割のトリガー」）。flow-id 1-5 の人間合意は本セッションでは
得られていないため、同じ内容を `HANDOFF.md`「判断を迷った内容」へも残す。

## 本セッションの特記事項（非対話的実行）

- 実行環境は Claude Code on the web のリモート実行環境で、`gh`/`glab` CLI が無いため
  VCS操作は MCP（`mcp__github__*`）経路を用いる。
- ユーザーの指示により、**各フェーズの結果確認工程（人間レビュー: flow-id 2-3/2-8/3-3/3-8/
  4-3/4-8）は `adversarial-review` スキルによる敵対的レビューで代替する**。
  進捗表のループ範囲の記号は、人間レビューを実施していない旨とあわせて `HANDOFF.md` の
  「やったこと」へ文章で残す。
- ブランチ名は `.mrworkflow.json` の `branchPrefixTemplate`（`feature-<issue番号>-<slug>`）に
  従っていないが、ハーネスから指定されたブランチであり変更できない。この事実を
  `HANDOFF.md` に残す。
