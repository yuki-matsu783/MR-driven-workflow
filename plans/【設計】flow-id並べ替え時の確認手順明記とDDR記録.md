---
title: 個別作業計画 flow-id並べ替え時の確認手順明記とDDR記録
type: plan
description: issue #143の再発防止策（案C）として、flow-id並べ替え作業時の確認手順をSKILL.mdへ追記し、意思決定をDDRとして記録する個別作業計画
tags: [docs-workflow, flow-id, ddr, 再発防止]
keywords: [SKILL.md, flow-id, 並べ替え, DDR, issue143, i0112-01, i0070-01, grep, 手順明記]
---

# 個別作業計画【設計】: flow-id並べ替え時の確認手順明記とDDR記録

対象: issue #143（docs-workflow.mdのreports/行flow-id矛盾の解消確認と再発防止策の検討）
全体作業計画: `plans/linear-painting-pond.md`
個別調査計画・調査結果: `plans/【調査】docs-workflow-mdのflow-id矛盾解消確認と再発防止策の選択肢整理.md` /
`reports/20260823_linear-painting-pond_flow-id矛盾解消確認と再発防止策調査.md`

## この計画で何をするか

フェーズ2の調査結果で有力案として選定した**案C（機械的検知は見送り、flow-id並べ替え作業を行う際の
確認手順をSKILL.mdへ明記し、意思決定をDDRとして記録する）**を具体化する。

`.claude/skills/issue-mr-flow/SKILL.md`へ、flow-idを並べ替える・新しいステップを挿入する作業を
行う際に踏むべき確認手順を追記し、あわせて今回の意思決定を新規DDR（`i0143-01`）として記録する。
コード変更は発生しない（ドキュメントのみの変更）。

## 変更対象

- `.claude/skills/issue-mr-flow/SKILL.md`: flow-idの並べ替え・挿入を行う際の確認手順を新設する節を追記する。
- `.claude/docs/ddr/i0143-01-<タイトル>.md`（新規作成）: 本タスクの意思決定を記録する。
- `.claude/docs/README.md`: `generate-ddr-list.sh`の再実行によりDDR一覧へ反映する（生成物）。
- `.claude/rules/docs-workflow.md`: 変更しない（フェーズ2調査結果のとおり、現行記述に矛盾は無い）。

## 方針

### 追記する確認手順の内容

flow-idの並べ替え・挿入作業（過去の実例: issue #112, issue #111, issue #70）を行う際、**変更作業の
最後に**次の手順を踏むことをSKILL.mdへ明記する。

1. `.claude/rules/docs-workflow.md` `.claude/skills/issue-mr-flow/SKILL.md`本体の変更を終えた後、
   リポジトリ全体で`flow-id [0-9]-[0-9]`という表記を横断grepし、**旧番号を指す記述が残っていないか**
   を1件ずつ確認する（`.md` `.sh` `.html`のいずれも対象。`.claude/scripts/`配下のコメント・
   `plans/REVIEW-POINTS.md` `reports/REVIEW-POINTS.md`（寿命が永続でディレクトリ除外からすり抜ける。
   issue #70で実際に踏んだ）を見落とさない）。
2. `plans/` `worklog/` `reports/`配下は**タスク単位の成果物のため走査対象から除外してよい**が、
   **除外はディレクトリ単位ではなくファイル単位で判断する**（`REVIEW-POINTS.md`はこれらの
   ディレクトリ直下にありながら寿命が永続のため、ディレクトリ除外だと巻き添えですり抜ける。
   issue #70の教訓、`.claude/rules/docs-workflow.md`に既に記載あり）。
3. `.claude/docs/spec/*.md` `.claude/docs/ddr/*.md`の**過去changelog・DDR本文**（point-in-time記録）は
   書き換えない。現在の状態を説明する節（`## 仕様`等）のみ、新しい番号へ更新してよい。
4. 確認した結果（何件見つかり、どう対処したか）を、そのissueの`reports/`（結果記録）または
   コミットメッセージへ残す。

この手順は、DDR `i0112-01`（issue #112でのフェーズ5並べ替え）・issue #111（統括レポート追加）・
issue #70（gemini変換同期ステップ追加）という**3回の並べ替え実績**を踏まえたもので、issue #70では
`reports/REVIEW-POINTS.md`の繰り下げ漏れが敵対的レビューで発見された実例が既に
`.claude/rules/docs-workflow.md`（「DDR番号の繰り下げ（改番）でも、この制限は同じように効く」の
直後の段落）へ教訓として記載されている。**この教訓はREVIEW-POINTS.mdの除外粒度という個別の
落とし穴について書かれたものであり、「並べ替え作業の最後に横断grepで確認する」という手順自体を
明記した箇所ではない。** 本計画は、この既存の教訓を活かしつつ、**手順そのもの**をSKILL.mdの
作業手順として明記する点で補完的である。

### 追記先の節

`.claude/skills/issue-mr-flow/SKILL.md`のフェーズ5節（「defaultブランチとのコンフリクト検知・解消」
等の既存の運用注記が並ぶ箇所）の近くへ、新しい見出し（例: `### flow-idを並べ替える・挿入する作業を
行う場合`）を追加する。挿入位置は、直前の節が節全体にかかる地の文で終わっていないかを確認してから
決める（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むときは」の教訓）。

### DDRの内容

新規DDR `i0143-01`には次を記録する。

- issue #143が報告した矛盾（`reports/`行のflow-id 5-1/5-3混在）は、issue #143とは無関係のPR #144
  （issue #111対応）により既に解消されていたこと。
- 受け入れ条件(1)「flow-id 5-3」は起票時点では正しく、その後issue #111対応でさらに5-4へ、
  本タスク中に取り込んだissue #70対応でさらに5-5へ繰り下がったこと（3段階の繰り下げの実例）。
- 再発防止策として、機械的検知スクリプトの新設（案A）・現状維持（案B）を却下し、
  手順明記＋DDR記録（案C）を採用した理由。
- 却下案（案A・案B）の詳細は`reports/…調査.md`の「再発防止策の選択肢整理」節を要約して記載する。

## やらないこと（スコープ外）

- `docs-workflow.md`本体の変更（フェーズ2調査結果のとおり、現行記述に矛盾は無いため）。
- 機械的検知スクリプトの新設（案Aとして却下済み）。
- 過去のDDR本文・spec changelogの書き換え（本文不変の原則。`.claude/rules/docs-workflow.md`）。
- `origin/main`の取り込み（issue #70によるflow-id 5-4→5-5繰り下げの反映）。これはflow-id 5-1
  （最終ゲート）で行う。本計画のDDR・SKILL.md追記は、取り込み前の現時点の情報（調査結果に記録した
  実例）をもとに設計する。

## 検証

- `bash .claude/scripts/src/generate-ddr-list.sh`を実行し、DDR一覧に`i0143-01`が反映されることを
  確認する。
- 追記したSKILL.mdの節が、直前の見出しの地の文を破壊していないか目視確認する。
- 新規DDRのfrontmatterが`.claude/rules/markdown-frontmatter.md`の規約（`type: ddr`、識別子の
  書式`i0143-01`）に従っていることを確認する。
- `.claude/rules/docs-workflow.md`の「DDRを追加・変更したら」の指示どおり、DDR一覧の差分が
  同じコミットへ含まれることを確認する。

## issueの受け入れ条件との対応

| # | 受け入れ条件 | 対応状況 |
|---|---|---|
| (1) | `reports/…md` / `reports/…html`行の運用欄がflow-id 5-3（もしくは現在正しい番号）を指す | フェーズ2で確認済み（既にPR #144で5-4へ解消済み）。本計画では変更しない |
| (2) | 「片付け＝flow-id 5-1」と読める現行記述が他に残っていない | フェーズ2で確認済み（残っていない） |
| (3) | `.claude/docs/spec/` `.claude/docs/ddr/`の過去changelogを変更しない | 本計画のDDR追記は新規ファイルであり、既存changelogは変更しない |
| (4) | 再発防止策の要否を検討し、結論を記録する | 本計画が対応（案Cの採用をSKILL.md追記＋DDRとして記録） |
