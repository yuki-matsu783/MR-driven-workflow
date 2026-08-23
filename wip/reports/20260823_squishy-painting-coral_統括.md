---
title: Gemini CLIテレメトリ機構（issue #105）最終統括レポート
type: report
description: issue #105「Gemini CLIのテレメトリをローカルファイルへ出力し、push毎に集計して対応工数レポートへ加える」の全フェーズ（調査・作業・反映・クローズ）を通した最終統括レポート
tags: [gemini-cli, telemetry, usage-report, issue-105, 統括]
keywords: [OpenTelemetry, outfile, semantic-conventions, 二重計上回避, バイトオフセットカーソル, 敵対的レビュー, mainマージ, dist-layers, wip移行]
---

# Gemini CLIテレメトリ機構（issue #105）最終統括レポート

フェーズ5・flow-id 5-4。issue #105の全作業（フェーズ1〜5）を通した最終統括。個別の調査結果・
作業結果・反映結果は各フェーズの `reports/` 正文を参照し、本レポートはそれらを横断した結論のみを
まとめる。

## サマリ（結論の一覧）

| # | 問い／やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | Gemini CLI公式テレメトリをローカルファイルへ出力できるか | できる。`.gemini/settings.json`の`telemetry`ブロック（`target: "local"`・`outfile: "usage/gemini-otel.log"`）を`sync-gemini-assets.sh`の生成ロジックへ固定値注入する形で実現した | 実装の確認 |
| 2 | push毎の差分集計は可能か | 可能。バイトオフセットカーソル方式（`_sync_usage_state_otel`系）を`UsageTracking.sh`へ新設し、ファイル縮小・途中書き込み・状態破損への耐性を実装した | 実装の確認・単体テスト（合成フィクスチャ） |
| 3 | セッションログ集計（issue #97）との二重計上は起きないか | 起きない。データソース（セッションログ vs テレメトリファイル）・状態ファイル・カーソル方式のいずれも完全独立で、semantic conventions形式のみ採用しレガシー形式・metricsを除外する設計で構造的に回避した | 実装の確認・単体テスト |
| 4 | 既定で有効化すべきか | **保留**（`enabled: false`固定）。`logPrompts`等の機微情報の扱いが実機未検証であり、既定で有効化すると全利用者に影響するため。DDR i0105-02に判断根拠を記録 | 設計判断（DDR） |
| 5 | 実機（`gemini`コマンド）での検証はできたか | できていない。この実行環境に`gemini`コマンドが存在しないため、`google-gemini/gemini-cli`公式ソース（GitHub, mainブランチ）の読解と単体テストの合成フィクスチャによる確認に限定される | 実装の確認・公式ドキュメント／ソースの読解 |
| 6 | defaultブランチとの整合は取れているか | 取れている。ブランチ作成後にmainが吸収した大規模な変更（issue #26配布機構刷新・#165 wip/移行・#170 usecase新設・#184 state移行・#160 SKILL.md分割）を2回のマージで統合し、単体テスト全20本`failures=0`・DDR識別子重複無し・ドキュメント参照切れ0件を確認した | 実測（マージ後の検証コマンド実行） |
| 7 | 敵対的レビューは各フェーズで実施したか | 実施した。フェーズ2〜4それぞれで計画時1回・作業実施時1回、合計6回（各フェーズ2/3回・上限内）実施し、指摘は全件（投稿分・報告のみ分とも）対応済み。投稿した全60スレッドに返信済み（未返信0件） | 実測（`adversarial-review-count.sh`・MRスレッド件数） |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（リモート実行環境。`gh`/`glab` CLI不在のためGitHub MCPツール経由）
- 対象リポジトリ: `yuki-matsu783/MR-driven-workflow`、対象PR: [#174](https://github.com/yuki-matsu783/MR-driven-workflow/pull/174)
- 対象issue: #105
- 実施期間: 2026-08-23（1セッション、push回数20）
- 対象・バージョン: Gemini CLI公式テレメトリ機構は`google-gemini/gemini-cli`のGitHub公式ソース（mainブランチ、実施日時点）を一次情報として使用。実機バージョンでの検証は無し

## 実施した内容と結果

### 1. フェーズ1〈起点〉— 全体作業計画

issue #105の内容を取得し、既存ブランチ`claude/gemini-cli-telemetry-reporting-a253xp`を用いて
Draft PR #174を作成した。Planモードで全体作業計画（`wip/plans/squishy-painting-coral.md`）を作成し、
issue #97（セッションログ集計）・issue #103（Claude Code OTelリスナー）との関係と、二重計上回避が
本issueの核心的な受け入れ条件であることを整理した。issue分割は不要と判断（1本のパイプラインの
各段階であり、単独マージに意味を持たないため）。ユーザーから、各フェーズの計画時・作業実施時に
それぞれ1回、敵対的レビューを自動実施する指示を受けた。

> **結論**: 全体作業計画はフェーズ2〈調査〉・フェーズ4〈反映〉の節を含めて作成し、承認を得た。

### 2. フェーズ2〈調査〉— 出力形式と統合方針

実機（`gemini`コマンド）がこの実行環境に存在しないため、`google-gemini/gemini-cli`公式ソースを
直接確認して8方針すべてに判断根拠を得た。主な結論は次のとおり。

- 同一イベントが**常に2回**LogRecordとしてemitされる（ロギングとテレメトリの二重パス）。
- metricsは**10秒間隔**の周期exportで、`gemini_cli.api_response`とは別レコード系統。
- `GEMINI_TELEMETRY_OUTFILE`環境変数が存在し、`settings.json`が静的でも動的パスを渡せる
  （当初の「渡せない」という判断は誤りだったため修正）。
- 既定有効化は「保留」（配布先で`.gitignore`保護が効かない配布漏れのリスクを発見したため）。

計画時・作業実施時それぞれ1回ずつ敵対的レビューを実施し、計26件の指摘（11件＋16件のうち重複除く）
に対応した。詳細は`wip/reports/20260823_squishy-painting-coral_Gemini-CLIテレメトリ出力形式と統合方針の調査結果.md`。

> **結論**: 二重計上回避に必要な「semantic conventions形式のみ採用」「metrics除外」という設計
> 要件は、この調査段階で確定した。

### 3. フェーズ3〈作業〉— 実装

調査結果をもとに3層構成（設定層・集計層・レポート層）＋配布gitignore是正で実装した。

- **設定層**: `sync-gemini-assets.sh`の生成ロジックへ`telemetry`固定値ブロック（`enabled: false`・
  `target: "local"`・`outfile: "usage/gemini-otel.log"`・`logPrompts: false`）を注入する設計に
  した（`.gemini/settings.json`の手編集ではなく、issue #70/#157で`.gemini/`が変換生成物になった
  ことに合わせた）。
- **集計層**: `UsageTracking.sh`へ、セッションログ集計（issue #97）とは完全独立のバイトオフセット
  カーソル関数群（`_sync_usage_state_otel`等）を追加。ファイル縮小・途中書き込み・状態ファイル
  破損への耐性、境界をまたぐ二重計上の回避を実装した。
- **レポート層**: `post-push-usage-report.sh`へ独立セクション「Gemini CLI公式テレメトリ（参考値）」
  として統合した（既存5引数呼び出しを壊さない設計）。
- 計画時・作業実施時それぞれ1回ずつ敵対的レビューを実施し、計32件の指摘（20件＋12件）に対応した。
  作業実施時レビューでは状態破壊バグ2件（fold結果を検証せず書き戻す不具合）を含む重大な指摘が
  あり、書き込み前検証の追加で修正した。
- 単体テスト120件（`test_usage_tracking.sh`）を含む全17本の`test_*.sh`が`failures=0`。

詳細は`wip/reports/20260823_squishy-painting-coral_Gemini-CLIテレメトリ集計機構の実装結果.md`。

> **結論**: 実装は完了し、既存経路（Claude Code・Gemini CLIセッションログ）の集計結果・レポート
> 内容を変化させないことを単体テストで確認した。

### 4. フェーズ4〈反映〉— spec・DDR・AIアセット

反映対象を洗い出し、評価軸の違いから2本の個別反映計画に分けた。

- **設計反映**: 新規spec`.claude/docs/spec/gemini-cli-telemetry.md`（`otel-listener.md`と対をなす
  構成）を作成。既存spec3本（`sync-gemini-assets.md`・`issue-mr-workflow.md`・
  `distribution-assets.md`）・`directory-structure.md`を更新。DDR新規2本
  （`i0105-01`二重計上回避方式・`i0105-02`既定有効化の保留）を記録。
- **AIアセット反映**: このセッションで実際に踏んだ`mcp__github__pull_request_read`のページネーション
  パラメータの罠（`cursor`ではなく`after`が正）を`issue-mr-flow/SKILL.md`の`references/mcp-fallback.md`
  ・`references/review-loop.md`へ注記した（後述のmainマージで両ファイルへ再適用）。
- **実装反映**: 不要と判断（フェーズ3のレビュー往復で全指摘に対応済み、持ち越した不具合は無い）。
- 計画時・作業実施時それぞれ1回ずつ敵対的レビューを実施し、計36件の指摘（19件＋17件）に対応した。
  作業実施時レビューでは、`enabled: false`固定の保留根拠がspec本文とDDRとで正反対だった矛盾など
  重大な指摘があり、いずれも修正した。

詳細は`wip/reports/20260823_squishy-painting-coral_Gemini-CLIテレメトリ機構の反映結果.md`。

> **結論**: spec・DDR・AIアセットへの反映は完了し、`.gemini/`側も`sync-gemini-assets.sh`で同期済み。

### 5. フェーズ5〈クローズ〉— defaultブランチ追従とマージ準備

flow-id 5-1で、ブランチ作成後にmainが吸収した大規模な変更（issue #26配布機構刷新・issue #165
`wip/`移行・issue #170 usecase新設・issue #184 state移行・issue #160 SKILL.md分割）を2回に分けて
マージし解消した。中心は**類型F（配置の変更 vs 上流の内容変更）**で、`wip/plans/` `wip/worklogs/`
`wip/reports/`配下はgit自身のディレクトリ改名検出により自動再配置され内容コンフリクトは無く、
`issue-mr-flow/SKILL.md`はこのブランチの2箇所の注記をmain側が分割した`references/*.md`へ再適用した。

このブランチ自身の変更（`install-to-project.sh`の`ignore_rules`配列への`/usage/`追加）は、main側
issue #26の全面書き換えで配列自体が無くなっており、`dist-layers.json`の`local`層に既に同等の
定義があったため、**コード変更を取り下げてmain版を採用**した（目的は達成済みのため実害無し）。

マージ検証中、`check-doc-references.sh`の実行（Step 5の検証手順）で、`git add -A`により
旧`sync-assets.sh`（issue #26で廃止済み）が生成した残骸約400ファイルを誤ってステージしていたことを
発見・除去した（敵対的レビューではなく、機械的な検証手順が捕捉した）。

flow-id 5-2では、`gemini-cli-telemetry.md`specが`.gemini/docs/spec/`へもミラーされる依存関係を
issue #172（`.gemini/`生成対象の見直しを検討中）へ通知した。

> **結論**: defaultブランチとの整合・関連issueへの通知はいずれも完了した。単体テスト全20本
> `failures=0`・DDR識別子重複無し・ドキュメント参照切れ0件を確認済み。

## 確かめられなかったこと

> **この結果が言っていないこと**
>
> - 実機（`gemini`コマンド）でのテレメトリ出力の生成・集計は検証できていない。この実行環境に
>   `gemini`コマンドが存在しないため、公式ソースの読解と単体テストの合成フィクスチャ（実装と同じ
>   仮定に基づく）による確認に限定される。人間による実機確認（フェーズ3計画時レビューで依頼した
>   7項目）が別途必要。
> - `logPrompts`を含む機微情報の実際の出力内容（プロンプト本文がどの程度含まれるか）は実機未検証。
>   これが既定有効化を保留（DDR i0105-02）した直接の理由である。
> - 大規模・長期運用でのファイルサイズ増大への対処（エクスポート間隔・ローテーション要否）は、
>   今回のスコープでは既定`false`のため実運用データが無く、評価していない。

## 設計への反映

1. 新規spec`.claude/docs/spec/gemini-cli-telemetry.md`、DDR2本（`i0105-01`・`i0105-02`）へ
   すでに反映済み（フェーズ4・flow-id 4-6）。本レポートは横断的な結論の記録であり、新規の
   反映事項は無い。
2. 今後、実機確認（上記「確かめられなかったこと」）の結果が得られた場合は、DDR i0105-02の
   `status`をfrontmatterのみ更新（`superseded`等）する運用に従うこと（本文は変更しない）。
3. flow-id 5-5でのクリーンアップ後、`wip/plans/` `wip/worklogs/` `wip/reports/`はmainへは残らず、
   ブランチのコミット履歴としてのみ残る。squash merge後に参照したい場合はPR #174のコミット一覧を
   辿ること。

## 残課題

- 実機（`gemini`コマンド）でのテレメトリ出力・集計の実地検証（別issueまたはユーザーによる
  確認事項として残す。DDR i0105-02の解除条件）。
- 既定有効化の可否判断（`logPrompts`実機確認の結果を踏まえてDDR i0105-02を見直す）。
- issue #172の決定（`.gemini/`生成対象から`docs/`を外すか）次第で、本issueが追加した
  `gemini-cli-telemetry.md`の`.gemini/`側ミラーの扱いに追従が必要になる可能性がある
  （flow-id 5-2で通知済み）。

---

issue #105 / PR #174 — 各フェーズの詳細は `wip/reports/` 配下の個別レポート・`HANDOFF.md` の
「やったこと」を参照。
