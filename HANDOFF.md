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

- issue: [#11 extract-frontmatter.shのリポジトリルート一括実行を高速化し中断耐性を持たせる](https://github.com/yuki-matsu783/MR-driven-workflow/issues/11)
- ブランチ: `feature-11-speed-up-frontmatter-index-build`
- Draft PR: [#19](https://github.com/yuki-matsu783/MR-driven-workflow/pull/19)
- push回数: 0
- 全体作業計画: `plans/lexical-stirring-peach.md`（flow-id 1-5で合意済み）

進捗欄の記号: `[]` 未着手 / `[x]` 完了 / `[-]` 今回は実施しない（スキップ）

| 進捗 | flow-id | ステップ | 担当 |
|----|---|---|---|
| [x] | 1-1 | issueを起票する（`.github/ISSUE_TEMPLATE/task.md` / `.gitlab/issue_templates/task.md` で目的・現状・期待する動作・受け入れ条件を記載） | 人間（AIが代行する場合は `issue-create` スキル） |
| [x] | 1-2 | issueの内容を取得する | `start <issue番号>` |
| [x] | 1-3 | featureブランチ（`feature-<issue番号>-<slug>`）とDraft MRを作成する（既にあれば `sync` のみ） | `start` |
| [x] | 1-4 | **Planモードで「全体作業計画」を作成する**（このissueをどう進めるか＝何を調査し何を実装するかの全体像。ハーネスが提示するパス `plans/<自動命名>.md` へ出力）。**現在のブランチに既に全体作業計画があれば新規作成せず、既存を読むだけにとどめる**（詳細は下記「計画の2階層構造」） | エージェント |
| [x] | 1-5 | 全体作業計画に合意する | 人間 |
| [x] | 1-6 | 全体作業計画をもとにHANDOFF.mdを更新する | エージェント |
| [-] | 2-1 | **個別調査計画**`plans/【調査】〜.md`を**planツールを使わず**Write/Editで作成する。このタイミングで `worklog/日付_<全体計画名>_<個別計画名>_push<N>.md` を作成 | エージェント |
| [-] | 2-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-3 | MRで調査計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-4 | レビュー内容を取得し、調査計画を修正する。対応が完了したコメントには対応内容を返信する（2-3〜2-4を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-5 | 調査計画をもとにMR descriptionを更新する | `describe` |
| [-] | 2-6 | **調査を実施**し、結果を個別調査計画・worklogに記録する。あわせて結果を視覚的に分かりやすくまとめた自己完結HTML（TailwindCSS CDN方式）を`reports/日付_<全体計画名>_<内容を簡潔に>.html`として作成する（複数要素間の関連・依存関係が主題の場合は、`.claude/skills/canvas-report/SKILL.md`のcanvas形式テンプレートの利用を検討する） | エージェント |
| [-] | 2-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [-] | 2-8 | MRで調査結果についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [-] | 2-9 | レビュー内容を取得し、調査結果を修正する。対応が完了したコメントには対応内容を返信する（`reports/`のHTMLも調査結果と同期して更新する。2-6〜2-9を合意まで繰り返す） | `comments` / `reply` |
| [-] | 2-10 | 調査結果をもとにMR descriptionを更新する | `describe` |
| [x] | 3-1 | **調査結果をもとに**、個別作業計画`plans/【設計】【実装】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
| [] | 4-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-3 | MRで反映計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-4 | レビュー内容を取得し、反映計画を修正する。対応が完了したコメントには対応内容を返信する（4-3〜4-4を合意まで繰り返す） | `comments` / `reply` |
| [] | 4-5 | 反映計画をもとにMR descriptionを更新する | `describe` |
| [] | 4-6 | 反映計画をもとに作業を進める、反映内容はworklogに更新する（**設計反映**: `plans/` `worklog/` の内容を `.claude/docs/spec/` `.claude/docs/ddr/`（アプリ本体があれば`docs/spec/` `docs/ddr/`）へ反映する／**AIアセット反映**: 作業中に気づいたルール・スキルの不備を `.claude/rules/` `.claude/skills/` `CLAUDE.md` `AGENTS.md` に反映する） | エージェント |
| [] | 4-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [] | 4-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [] | 4-9 | レビュー内容を取得し、設計・AIアセットの内容を修正する。対応が完了したコメントには対応内容を返信する（4-6〜4-9の反映ループを合意まで繰り返す） | `comments` / `reply` |
| [] | 4-10 | 反映内容をもとにMR descriptionを更新する | `describe` |
| [] | 5-1 | 次タスクのために、`plans/` `worklog/` `reports/` を削除し、`HANDOFF.md` をリセットする | エージェント |
| [] | 5-2 | `commit`スキル経由でcommitし、push して Draftを解除する | エージェント |
| [] | 5-3 | マージする（squash merge。ブランチは削除してよい） | 人間 |

詳細についてはworklogを確認してください。

## やったこと

- flow-id 1-2〜1-3: `start 11` でissue #11を取得（標準4見出しは過不足なし）。ベースブランチを
  `AskUserQuestion` で確認し `main` のまま確定 → `feature-11-speed-up-frontmatter-index-build` と
  Draft PR #19 を作成。
- flow-id 1-4〜1-5: 全体作業計画 `plans/lexical-stirring-peach.md` を作成し合意を得た。
  計画作成時にボトルネックを実測で特定済み（**git bashの外部プロセス起動が約95ms/回**。
  `jq -nc '1'` を50回で4.73秒。現行実装はfrontmatterのキー・配列要素ごとにjqを起動しており
  1ファイル約30回 × 43ファイル ≈ 約2分でタイムアウトしていた）。
- flow-id 1-6: 本ファイルを更新（フェーズ1完了）。
- flow-id 3-1: 個別作業計画
  `plans/【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md` と、worklog
  `worklog/20260818_lexical-stirring-peach_【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性_push1.md`
  を作成した。

## 次にやること

- **flow-id 3-2**: `commit`スキル経由でcommitし、pushしてレビュー依頼を行う（push1）。
- レビュー合意（flow-id 3-3〜3-4）後、flow-id 3-5でMR descriptionを更新し、flow-id 3-6で実装に着手する。
  実装着手時の最初の2作業は個別作業計画「実装手順」の1.（ベースライン計測）と2.（既知バグの再現確認）。

## 判断を迷った内容

- **フェーズ2（調査）を実施するか**: ボトルネックが計画作成時の実測でほぼ特定できていたため、
  ユーザ合意のうえ**フェーズ2はスキップ**しフェーズ3から着手する（進捗表では `[-]`）。
  ベースライン実測は実装フェーズの冒頭で行いworklogへ記録する。
- **specの既知バグを今回のスコープに含めるか**: ユーザ合意のうえ**含める**
  （「ディレクトリを絞って実行するとスコープ外の`index.jsonl`まで変更され重複行が生じる」。
  原因未特定のままspecの未決定事項に残っているもの）。
- **HANDOFF更新の自動化依頼の扱い**: セッション途中で「HANDOFFの進捗を更新するスクリプトを作り
  haikuサブエージェントで使いたい」という依頼を受けたが、issue #11 とは別主題のため
  **issue #20 として起票し、issue #11 完了後に別ブランチで着手する**ことで合意した
  （https://github.com/yuki-matsu783/MR-driven-workflow/issues/20 ）。今回のPR #19 には含めない。

## 未解決の内容

- 既知バグ（ディレクトリを絞った実行がスコープ外の`index.jsonl`に影響する件）は、現在のクリーンな
  作業ツリーでは**再現していない**（`git ls-files --cached --others` の出力に重複0件、ルート
  `index.jsonl` にも重複行なしを確認済み）。実装フェーズでまず再現手順の確立から行う。
  再現・解消できなければ、判明した再現条件をspecの未決定事項へ追記して残す。
- 進捗表で使った `[-]`（今回は実施しない）は `.claude/rules/docs-workflow.md` の記号規約に未記載。
  issue #20 で明文化する予定。

## 守るべき条件・触ってはいけない範囲

- **`index.jsonl` の出力フォーマットを変更しない**。issueの受け入れ条件が「生成される内容が現行実装と
  同一（回帰なし）」のため。回帰検証は「クリーンな作業ツリーで全再生成 → `git diff -- '*index.jsonl'`
  が空」で行う。
- **frontmatterの解析ロジック（行の正規表現・`trim`/`unquote`・`yq`優先パス）は変更しない**。
  変更するのは「JSONの組み立て方」「ファイル情報の取得方法」「出力の書き方」の3点に限定する。
- `.sh` は BOM無しUTF-8・LF改行で保存し、`set -euo pipefail` を維持する
  （`.claude/rules/shell-script-style.md`）。
- コミットは必ず `commit` スキル経由で行う（直接のコミット実行はPreToolUse hookでブロックされる）。
- issue #20（HANDOFF更新の自動化）の実装は、このブランチでは行わない。
