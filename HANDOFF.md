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
- push回数: 4
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
| [x] | 3-2 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-3 | MRで作業計画についてレビュー・コメントする。レビュー完了済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 3-4 | レビュー内容を取得し、作業計画を修正する。対応が完了したコメントには対応内容を返信する（3-3〜3-4を合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-5 | 作業計画をもとにMR descriptionを更新する | `describe` |
| [x] | 3-6 | 作業計画をもとに作業を進める、作業内容はworklogに更新する | エージェント |
| [x] | 3-7 | `commit`スキル経由でcommitし、push してレビュー依頼を行う | エージェント |
| [x] | 3-8 | MRでレビュー・コメントする。レビュー済み連絡をするまで以降の作業は行わない。 | 人間 |
| [x] | 3-9 | レビュー内容を取得し、実装・ドキュメントを修正する。対応が完了したコメントには対応内容を返信する（3-6〜3-9の作業ループを合意まで繰り返す） | `comments` / `reply` |
| [x] | 3-10 | 作業内容をもとにMR descriptionを更新する | `describe` |
| [x] | 4-1 | **作業結果と`plans/` `worklog/` の内容をもとに**、個別反映計画`plans/【設計反映】【AIアセット反映】〜.md`等を**planツールを使わず**Write/Editで作成する | エージェント |
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

- flow-id 1-2〜1-6（フェーズ1完了）: `start 11` でissue #11取得 → ベースブランチを `main` に確定 →
  `feature-11-speed-up-frontmatter-index-build` と Draft PR #19 を作成 → 全体作業計画
  `plans/lexical-stirring-peach.md` を作成し合意。
- flow-id 3-1〜3-2（push1）: 個別作業計画
  `plans/【設計】【実装】【テスト】extract-frontmatter高速化と中断耐性.md` と worklog push1 を作成しpush。
- flow-id 3-3〜3-5: レビュー合意（未解決スレッド0件を `comments all` 相当で確認済み）→
  MR description を更新。
- flow-id 3-6（実装完了）: `.claude/scripts/src/extract-frontmatter.sh` を改修し、
  `tests/test_extract_frontmatter.sh` を新設。詳細は worklog push2。
  - **性能**: ルート指定 136秒 → **9.6〜11.8秒**（全再生成） / **1.5〜2.4秒**（差分なし）。
    ddr単体 46.4秒 → 3.0秒。
  - **回帰なし**: 改修前の出力（golden 15ファイル）とバイト単位で完全一致。
  - **中断耐性**: `SIGINT` 中断でも全 `index.jsonl` のmd5が不変・一時ファイル残存なし
    （改修前は同条件で16行→2行に破損することも実機で確認）。
  - **単体テスト**: `passed=17 failures=0`。
  - **既知バグ**（スコープ外への影響・重複行）は改修前後とも**再現せず**。差分の正体は
    「gitのcheckout/mergeによるmtime更新」と「陳腐化エントリの除去」だった。
- flow-id 3-7（push2）: 実装一式をcommit・push（perf / test / chore / docs の4コミットに分割）。
- flow-id 3-8〜3-9（push3）: レビュー指摘「フェーズ途中の一時ファイルはjsonl作成の対象にしてよい。
  .gitignoreは除外」「MR直前のpushではindex.jsonlも消す」を受領。**現行実装のままで要求を満たして
  いる**ことを実機確認（`.gitignore` 対象の `/logs/` `/build/` に .md を置いても走査されない）ため、
  スクリプトの変更は不要と判断し、決定内容をworklog push3へ記録した。
- flow-id 3-10（フェーズ3完了）: 未解決スレッド0件（自動投稿の対応工数レポート4件のみ）を再確認し、
  PR #19 のdescriptionをフェーズ3完了時点の内容（対応方針・性能実測値・受け入れ条件との対応・
  既知バグの結論・レビューで確定した運用）へ更新した。
- flow-id 4-1（push4）: 個別反映計画
  `plans/【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性.md` と worklog push4 を作成。
  反映元の確定事項をA〜Iに整理し、spec更新・DDR 0021新設・rules 2件/SKILL 1件/docs-workflow 1件への
  追記に割り付けた。この過程で**既存specの記述誤り2件**（存在しないパス
  `.claude/scripts/docs/spec/shell-scripts.md` への参照、および**このリポジトリに存在しない**
  `ddr/0008-…` へのリンク2箇所）を発見し、反映対象に含めた。

## 次にやること

- **flow-id 4-2**: 個別反映計画・worklog push4・HANDOFF.md をcommitし、pushしてレビュー依頼（push4）。
- レビュー合意後、flow-id 4-5（MR description更新）→ 4-6（反映作業の実施）へ進む。

## 判断を迷った内容

- **フェーズ2（調査）を実施するか**: ボトルネックが計画時点の実測で特定できていたため、
  ユーザ合意のうえ**スキップ**（進捗表では `[-]`）。
- **specの既知バグを今回のスコープに含めるか**: ユーザ合意のうえ**含めた**（結果は上記のとおり再現せず）。
- **回帰検証の方法**: 個別作業計画では「`git diff -- '*index.jsonl'` が空」としていたが、
  コミット済みの `index.jsonl` が陳腐化しており、かつ `mtime` がブランチ操作で変わるため**成立しない**と
  判明。**ゴールデンファイル方式**（改修前の出力を退避してバイト比較）へ変更した。
- **HANDOFF更新の自動化依頼の扱い**: issue #11 とは別主題のため **issue #20 として起票**し、
  issue #11 完了後に別ブランチで着手する（https://github.com/yuki-matsu783/MR-driven-workflow/issues/20 ）。
  今回のPR #19 には含めない。

## 未解決の内容

- （解決済み）再生成された `index.jsonl` の扱いは、レビューで**「一時ファイル（`plans/` `worklog/`）も
  jsonl作成の対象にしてよい。`.gitignore` は除外」「MR直前のpushでは `index.jsonl` も消す」**と確定した。
  すべてコミット済み。
- **flow-id 5-1 の手順追記がフェーズ4のTODO**: `plans/*.md` を全削除しても、本スクリプトは
  「markdownが直下にあるディレクトリ」だけを出力対象にするため、`plans/index.jsonl` は再生成の
  対象外となり陳腐化したまま残る。5-1で**`plans/index.jsonl` も削除し `index.jsonl` 群を再生成する**
  手順を `.claude/skills/issue-mr-flow/SKILL.md` と `.claude/rules/docs-workflow.md` へ追記する
  （個別反映計画の 2-3 / 2-4 に反映済み。flow-id 4-6で実施する）。
- **`index.jsonl` をコミット対象にしている運用上の副作用**: `HANDOFF.md` や worklog を編集するたびに
  mtime 経由で `index.jsonl` が陳腐化するため、**commit直前に `extract-frontmatter.sh .` を1回流す**
  必要がある（高速化した今なら1〜2秒）。specの懸念点として記載する方針（自動化はissue #11の
  受け入れ条件外のため今回は行わない）。
- 進捗表で使った `[-]`（今回は実施しない）は `.claude/rules/docs-workflow.md` の記号規約に未記載。
  issue #20 で明文化する予定。

## 守るべき条件・触ってはいけない範囲

- **`index.jsonl` の出力フォーマットは変更しない**（回帰なしが受け入れ条件）。検証はゴールデン
  ファイル方式で行う（改修前の出力はスクラッチ領域に退避済み。セッションを跨ぐ場合は改修前の
  実装 `git show <base>:.claude/scripts/src/extract-frontmatter.sh` から採取し直す）。
- **frontmatterの解析ロジック（行の正規表現・値の分類・`yq`優先パス）は変更しない**。
- **ホットパスでコマンド置換 `$(...)` を使わない**（サブシェルforkが1回あたり数十msかかる）。
  `trim_unquote_to_reply` / `unquote_to_reply` のように `REPLY` へ返す形を使う。
- **ループ内で `jq` を起動しない**（1ファイルあたり1回に集約する設計を壊さない）。
- `.sh` は BOM無しUTF-8・LF改行で保存し、`set -euo pipefail` を維持する。
- コミットは必ず `commit` スキル経由で行う。
- issue #20（HANDOFF更新の自動化）の実装は、このブランチでは行わない。
