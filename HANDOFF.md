---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

## フロー進捗状況

- issue: #97（対応工数レポートをGemini CLIのセッションログにも対応させ、ツール実行回数等を集計する）
- ブランチ: `feature-97-support-gemini-cli-usage-report`
- PR: #101 https://github.com/yuki-matsu783/MR-driven-workflow/pull/101 （Draft）
- 追従監視: なし（ローカル。各pushとflow-id 5-2で手動確認する）
- push回数: 2
- 現在のループ: なし

| 進捗 | flow-id | ステップ | 担当 |
|---|---|---|---|
| [x] | 1-1 | issueを起票する | 人間 |
| [x] | 1-2 | issueの内容を取得する | `start` |
| [x] | 1-3 | featureブランチとDraft MRを作成する | `start`（エージェント） |
| [x] | 1-4 | Planモードで「全体作業計画」を作成する | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [x] | 2-1 | 個別調査計画を作成する | エージェント |
| [] | 2-2 | commit・pushしてレビュー依頼 | エージェント |
| [] | 2-3 | 調査計画のレビュー | 人間 |
| [] | 2-4 | レビュー内容を反映する | `comments` / `reply` |
| [] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [] | 2-6 | 調査を実施する | エージェント |
| [] | 2-7 | commit・pushしてレビュー依頼 | エージェント |
| [] | 2-8 | 調査結果のレビュー | 人間 |
| [] | 2-9 | レビュー内容を反映する | `comments` / `reply` |
| [] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [] | 3-1 | 個別作業計画を作成する | エージェント |
| [] | 3-2 | commit・pushしてレビュー依頼 | エージェント |
| [] | 3-3 | 作業計画のレビュー | 人間 |
| [] | 3-4 | レビュー内容を反映する | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める | エージェント |
| [] | 3-7 | commit・pushしてレビュー依頼 | エージェント |
| [] | 3-8 | 作業内容のレビュー | 人間 |
| [] | 3-9 | レビュー内容を反映する | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | 個別反映計画を作成する | エージェント |
| [] | 4-2 | commit・pushしてレビュー依頼 | エージェント |
| [] | 4-3 | 反映計画のレビュー | 人間 |
| [] | 4-4 | レビュー内容を反映する | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 設計反映・AIアセット反映を行う | エージェント |
| [] | 4-7 | commit・pushしてレビュー依頼 | エージェント |
| [] | 4-8 | 反映内容のレビュー | 人間 |
| [] | 4-9 | レビュー内容を反映する | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | plans/ worklog/ reports/ を削除しHANDOFF.mdをリセットする | エージェント |
| [] | 5-2 | defaultブランチとのコンフリクトを検知・解消する | エージェント |
| [] | 5-3 | 関連issueを特定しマージ前の通知を投稿する | エージェント |
| [] | 5-4 | commit・pushしてDraftを解除する | エージェント |
| [] | 5-5 | マージする | 人間 |

## やったこと

- flow-id 1-2: issue #97 の内容を取得し、標準4見出し（目的・現状・期待する動作・受け入れ条件）が
  揃っていることを `test_issue_sections` で確認した。
- flow-id 1-3: ベースブランチを `main` で確認のうえ
  `feature-97-support-gemini-cli-usage-report` を作成し、Draft PR #101 を作成した
  （baseとの差分が無いことによる1回目の失敗は既知の制約で、空コミットによる自動リトライで成功）。
- flow-id 1-4: 全体作業計画 `plans/partitioned-forging-seahorse.md` を作成した。
  **issue本文の前提が2点覆っている**ことを着手時点で確認し、計画へ記録した。
  - Gemini CLI **v0.39.0** でセッションログが単一JSON → **追記型JSONL**
    （`~/.gemini/tmp/<project_hash>/chats/session-<TIMESTAMP>-<sessionId先頭8文字>.jsonl`）へ移行済み。
  - **トークン相当のフィールドは実在する**（`tokens: {input, output, cached, thoughts, tool, total}`）。
    issue本文の「使用量フィールドが無い」は旧形式の話。
- flow-id 1-5: ユーザーが全体作業計画を承認した。
- issueの分割判定: **分割しない**（受け入れ条件はいずれも `UsageTracking.sh` の同じ集計経路へ
  同時に効く横断的変更のため）。
- flow-id 1-6: 本ファイル（`HANDOFF.md`）へ41ステップの進捗表とヘッダを作成した。
- flow-id 2-1: 個別調査計画 `plans/【調査】Gemini CLIのセッションログとテレメトリの形式.md` を
  作成した（調査項目A〜Nをissueの受け入れ条件と対応づけ、実施順を定めた。参照対象として
  `参考ディレクトリ/gemini-insights` を明示している）。あわせて worklog
  `worklog/20260820_partitioned-forging-seahorse_【調査】Gemini CLIのセッションログとテレメトリの形式_push2.md`
  を作成した。

## 次にやること

- **flow-id 2-3（人間による個別調査計画のレビュー）待ち。** PR #101 のレビュー・コメントを待つ。
- レビュー合意後、flow-id 2-5（MR description更新）→ flow-id 2-6（調査の実施）へ進む。
- 調査の実施では、個別調査計画の調査項目 A〜N を A・B・L（事実確認）→ K（既存経路の分岐点）→
  C〜J・M（設計判断）→ N の順で進める。結果は
  `reports/20260820_partitioned-forging-seahorse_Geminiセッションログとテレメトリの調査.md`
  （正文）と同名の `.html` へ記録する（計画ファイル・worklogには結果を書かない）。

## 判断を迷った内容

- **セッションログの形式**: 当初はissue本文どおり「単一JSON」を前提に計画を書いたが、ユーザーの
  指摘とウェブ調査（gemini-cli PR #23749 / cc-switch#2347）で**現行はJSONL**と判明したため
  計画を書き直した。旧 `.json` はCLI本体側に読み込みフォールバックが残るため、**拡張子で
  ディスパッチして両対応**にする方向で検討する（フェーズ2の論点）。
- **`$rewindTo` の扱い**: 会話としては切り詰められるが、課金・ツール実行は起きている。対応工数
  レポートの目的に照らすと集計から外さない方が妥当と考えているが、フェーズ2で明示的に決めてDDRへ残す。

## 未解決の内容

- **スコープ追加（issue本文に無い要件）**: Gemini CLIのテレメトリ（`telemetry.enabled` /
  `target: "local"` / `outfile`）をローカルへ出力し、push毎に集計してレポートへ加える。
  着手時のチャットで受けた指示のため、**レビュー往復の際に `add_mr_comment` でMRへ記録する**
  （`.claude/skills/issue-mr-flow/SKILL.md`「チャットで受けたレビュー判断の記録」）。
  issue #97 本文の受け入れ条件も更新が要るか、フェーズ2で判断する。
- **`logPrompts` の既定が `true`** であり、有効化すると**プロンプト本文がローカルファイルへ
  平文で残る**。`usage/` は `.gitignore` 対象だが、`false` を既定にする方向で検討する。
- **実機検証ができない**: この開発機に `~/.gemini` は存在しない（確認済み）。合成フィクスチャでの
  検証にとどまるため、未検証範囲は reports と spec の「未決定事項・懸念点」へ明示する。

## 守るべき条件・触ってはいけない範囲

- **Claude Code側の集計ロジック・レポート内容を変えない**（既存テストのアサーションを変更しない
  ことで担保する）。Gemini用の集計は関数を分けて engine で分岐させる。
- `.gemini/settings.json` は `.gemini/` 配下で唯一Git管理下にあるファイルであり、変更すると
  利用者全員のGemini CLIの挙動が変わる。テレメトリを既定で有効にしてよいかは要判断。
- テレメトリの `target` は `local` のみを対象とする（`gcp` はGoogle Cloudへ送信されるため使わない）。
