---
title: 個別作業計画 flow-id並べ替え時の確認手順明記とDDR記録
type: plan
description: issue #143の再発防止策（案C）として、flow-id並べ替え作業時の確認手順をSKILL.mdへ追記し、意思決定をDDRとして記録する個別作業計画
tags: [docs-workflow, flow-id, ddr, recurrence-prevention]
keywords: [SKILL.md, flow-id, 並べ替え, DDR, issue143, i0112-01, i0070-01, grep, 手順明記, 再発防止]
---

# 個別作業計画【設計】: flow-id並べ替え時の確認手順明記とDDR記録

対象: issue #143（docs-workflow.mdのreports/行flow-id矛盾の解消確認と再発防止策の検討）
全体作業計画: `plans/linear-painting-pond.md`
個別調査計画・調査結果: `plans/【調査】docs-workflow-mdのflow-id矛盾解消確認と再発防止策の選択肢整理.md` /
`reports/20260823_linear-painting-pond_flow-id矛盾解消確認と再発防止策調査.md`

## 前提（合意状況）

- 全体作業計画: `plans/linear-painting-pond.md`（flow-id 1-5で人間の承認を得て合意済み）。
- 依拠する調査結果: `reports/20260823_linear-painting-pond_flow-id矛盾解消確認と再発防止策調査.md`
  （フェーズ2、敵対的レビュー2回・全指摘対応を経て確定。ループ2-6〜2-9として完了済み。案C
  「手順明記＋DDR記録」を有力案として選定した）。
- 本計画自体（フェーズ3・計画時）はまだ人間レビューを経ていない（非対話セッションのため敵対的
  レビューで代替）。ここに書く方針は本計画のレビューを経て確定する。

## この計画で何をするか

フェーズ2の調査結果で有力案として選定した**案C（機械的検知は見送り、flow-id並べ替え作業を行う際の
確認手順をSKILL.mdへ明記し、意思決定をDDRとして記録する）**を具体化する。

`.claude/skills/issue-mr-flow/SKILL.md`へ、flow-idを並べ替える・新しいステップを挿入する作業を
行う際に踏むべき確認手順を追記し、あわせて今回の意思決定を新規DDR（`i0143-01`）として記録する。
コード変更は発生しない（ドキュメントのみの変更）。

## 変更対象

- `.claude/skills/issue-mr-flow/SKILL.md`: flow-idの並べ替え・挿入を行う際の確認手順を新設する節を追記する（本文案は「方針」節参照）。
- `.claude/docs/ddr/i0143-01-flow-id並べ替え時の確認手順をSKILL.mdへ明記しDDRで記録する.md`（新規作成）: 本タスクの意思決定を記録する。
- `.claude/docs/README.md`: `generate-ddr-list.sh`の再実行によりDDR一覧へ反映する（生成物）。
- `.claude/rules/docs-workflow.md`: 変更しない（フェーズ2調査結果のとおり、現行記述に矛盾は無い。既存の教訓段落はそのまま活かす。下記「方針」参照）。

## 方針

### 追記する確認手順の内容（SKILL.mdへの本文案）

flow-idの並べ替え・挿入作業（過去の実例: issue #112, issue #111, issue #70）を行う際、**変更作業の
最後に**次を確認することをSKILL.mdへ明記する。追記先は下記「追記先の節」のとおり、SKILL.mdの
フェーズ5節の直後（`## サブコマンド`の直前）に新しい見出し
`### flow-idを並べ替える・挿入する作業を行う場合`を置く。本文案は次のとおり（実際の追記時に
文言を微調整することはあるが、内容の骨子はこの4点から変えない）。

> flow-idの並べ替え・新規ステップの挿入（過去の実例: issue #112「フェーズ5並べ替え」・issue #111
> 「統括レポート追加」・issue #70「gemini変換同期ステップ追加」）を行う際は、
> `.claude/rules/docs-workflow.md` `.claude/skills/issue-mr-flow/SKILL.md`本体の変更を終えた後、
> **変更作業の最後に**次を確認する。
>
> 1. リポジトリ全体で`[0-9]-[0-9]`という数字パターン（`flow-id`の接頭辞が付かないもの——
>    `2-3〜2-4`のような範囲表記・`flow-id 2-2/2-7/…`のようなスラッシュ連結表記を含む）を
>    横断grepし、旧番号を指す記述が残っていないか1件ずつ確認する。
>    ```bash
>    git grep -nE '[0-9]-[0-9]' -- '*.md' '*.sh' '*.html' | grep -vE '^(plans|worklog|reports)/'
>    ```
>    ヒット件数はSKILL.md単体で数十件規模になりうるため、今回変更した番号（旧番号→新番号）を
>    先に列挙してから、その旧番号だけを対象に絞り込むと確認が現実的になる。
> 2. `plans/` `worklog/` `reports/`配下はタスク単位で削除される成果物のため走査対象から除外して
>    よいが、**除外はディレクトリ単位ではなくファイル単位で判断する**。`plans/REVIEW-POINTS.md`
>    `reports/REVIEW-POINTS.md`はこれらのディレクトリ直下にありながら寿命が永続のため、
>    ディレクトリ除外だと巻き添えですり抜ける（issue #70で実際に踏んだ実例は
>    `.claude/rules/docs-workflow.md`「DDR番号の繰り下げ（改番）でも、この制限は同じように効く」
>    直後の段落が正——本節では重複説明しない）。
> 3. ヒットした記述が**現在の状態を説明しているか、過去の記録（point-in-time）か**で判断する
>    （ファイルの種類では判断しない）。`.claude/docs/spec/*.md` `.claude/docs/ddr/*.md`の過去
>    changelog・DDR本文だけでなく、`.claude/scripts/`配下のコメント（例:
>    `cleanup-task.sh`冒頭の「当時のflow-idは5-1。issue #112の並べ替えで5-3に…」、
>    `vcs/Gitlab.sh` `vcs/Github.sh`の同種のコメント）も同じ性質のpoint-in-time記録であり、
>    書き換えない。現在の状態を説明する節・コメントのみ、新しい番号へ更新する。
> 4. 確認した結果（何件見つかり、どう対処したか）を、そのissueの`reports/`（結果記録）または
>    コミットメッセージへ残す。

### 追記先の節

`.claude/skills/issue-mr-flow/SKILL.md`の`## 全体フロー`〜フェーズ5関連の各節（「defaultブランチ
とのコンフリクト検知・解消」等）の直後、`## サブコマンド`見出しの直前へ、新しい見出し
`### flow-idを並べ替える・挿入する作業を行う場合`を追加する。この位置を選ぶ理由は、
`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むときは」の教訓に従い、
直前の節（コンフリクト解消節）が節全体にかかる地の文で終わっていないことを確認したため
（実装時に改めて実測確認する）。

### docs-workflow.mdとの役割分担（重複の解消）

`.claude/rules/docs-workflow.md`には既に、issue #70対応時に実際に踏んだ実例
（`reports/REVIEW-POINTS.md`の繰り下げ漏れが敵対的レビューで発見された）を教訓として記載した
段落がある（**このブランチにはまだ取り込まれておらず、`origin/main`側にのみ存在する**。詳細は
下記「重要な前提: origin/mainとの関係」参照）。この段落とSKILL.mdへの追記は役割を分ける。

- **SKILL.mdの新節が正**: 「flow-id並べ替え作業の最後に何を確認するか」という**手順そのもの**。
- **docs-workflow.mdの既存段落が正**: 「なぜその確認が要るか」を示す**具体的な失敗実例**の説明。

SKILL.mdの新節からは、実例の詳細を再説明せず「詳細な実例は`.claude/rules/docs-workflow.md`
『flow-idの繰り下げのような横断的な棚卸しでは』の段落が正」という参照に留める。同じ内容を
2箇所で説明しない。

### 重要な前提: origin/mainとの関係

本ブランチの分岐後、`origin/main`はissue #70対応（`.gemini/`変換同期ステップの新設）により
「片付け」のflow-id番号がさらに5-4→5-5へ繰り下がっている（`git merge-tree`で確認済み、
`reports/…調査.md`の想定と異なった点として記録済み）。**この繰り下げも、docs-workflow.mdの
教訓段落も、いずれも`origin/main`側にのみ存在し、本ブランチには未取り込みである。**

- 本計画・DDR本文では、この事実を**確認手段と時点を明示した形**で記述する（例:
  「`git merge-tree --write-tree HEAD origin/main`で、`origin/main`上ではissue #70対応により
  flow-id 5-4→5-5へ繰り下がっていることを確認した（2026-08-23時点、本ブランチ未取り込み）」）。
  「本タスク中に取り込んだ」「5-5になった」のように、あたかも本ブランチへ反映済みであるかのような
  断定はしない。
- SKILL.mdへ追記する新節も、docs-workflow.mdの教訓段落を参照する形にするが、**この参照は
  flow-id 5-1でのorigin/main取り込みが完了して初めて有効になる**（取り込み前は参照先が
  存在しない）。取り込み前にこのPRがマージされることは無い設計（flow-id 5-1が最終ゲート）だが、
  念のため下記「検証」節に取り込み後の再確認手順を明記する。

### DDRの内容

新規DDR `i0143-01`（タイトル案:
「i0143-01. flow-id並べ替え時の確認手順をSKILL.mdへ明記しDDRで記録する」）には次を記録する。

- issue #143が報告した矛盾（`reports/`行のflow-id 5-1/5-3混在）は、issue #143とは無関係のPR #144
  （issue #111対応）により既に解消されていたこと。
- 受け入れ条件(1)「flow-id 5-3」は起票時点では正しく、その後(a)issue #112対応で5-1→5-3、
  (b)issue #111対応で5-3→5-4、(c)本ブランチ作業中に判明したissue #70対応（`origin/main`側、
  本ブランチ未取り込み）で5-4→5-5、と**3回**繰り下がったこと（起票前の1回を含めれば計3回、
  起票後だけなら2回。DDR本文には数える起点を明記し、曖昧な「N段階」という表現は使わない）。
- 再発防止策として、機械的検知スクリプトの新設（案A）・現状維持（案B）を却下し、
  手順明記＋DDR記録（案C）を採用した理由。
- 却下案（案A・案B）の詳細は`reports/…調査.md`の「再発防止策の選択肢整理」節を要約して記載する。

### フェーズ4〈反映〉との関係

`.claude/rules/docs-workflow.md`は「plans／worklogの内容はflow-id 4-6（設計反映）で
`.claude/docs/spec/` `.claude/docs/ddr/`へ反映する」と定めており、通常はフェーズ3で実装・
フェーズ4でspec/ddrへ反映する2段構えになる。**本タスクはドキュメントのみの変更で、成果物
そのものがSKILL.mdへの追記とDDR新規作成（=spec/ddr相当）であるため、フェーズ3の時点で反映まで
完了する。** フェーズ4（flow-id 4-1）では改めて反映対象を洗い出すが、本計画のとおり実施すれば
新たに反映すべき対象は無いと見込まれるため、その時点でフェーズ4の残り（4-2〜4-10）をスキップする
可能性が高い。**正式な判断はflow-id 4-1で行い、ここでは先回りして`[-]`にしない**
（`.claude/skills/issue-mr-flow/SKILL.md`「全体作業計画に必ず含めるフェーズ」の原則どおり）。

## やらないこと（スコープ外）

- `docs-workflow.md`本体の変更（フェーズ2調査結果のとおり、現行記述に矛盾は無いため）。
- 機械的検知スクリプトの新設（案Aとして却下済み）。
- 過去のDDR本文・spec changelogの書き換え（本文不変の原則。`.claude/rules/docs-workflow.md`）。
- `origin/main`の取り込み（issue #70によるflow-id 5-4→5-5繰り下げの反映）。これはflow-id 5-1
  （最終ゲート）で行う。本計画のDDR・SKILL.md追記は、取り込み前の現時点で確認できた事実
  （調査結果に記録した実例、確認手段・時点を明示した形）をもとに設計する。

## 検証

```bash
# 1. DDR一覧に i0143-01 が反映されることを件数で確認する（目視ではなく件数で判定する）
bash .claude/scripts/src/generate-ddr-list.sh
grep -c -- 'i0143-01' .claude/docs/README.md   # 1以上であること

# 2. 「変更しないと宣言したファイル」が実際に変わっていないことを、分岐点固定のdiffで確認する
#   （目視確認ではなく削除行数で判定する。新規追加したDDR以外の削除行が0であること）
git diff 0aa9874d18032a9a85d5bc98075511fa11ce0cc3 -- .claude/docs/spec/ .claude/docs/ddr/ | grep -c '^-[^-]'

# 3. 新規DDRのfrontmatterが規約に従っているか確認する
grep -A3 '^---$' .claude/docs/ddr/i0143-01-*.md | head -10
```

- 追記したSKILL.mdの節が、直前の見出しの地の文を破壊していないか目視確認する（この項目のみ、
  機械的な件数化が難しいため目視に留める）。
- 新規DDRのfrontmatterが`.claude/rules/markdown-frontmatter.md`の規約（`type: ddr`、識別子の
  書式`i0143-01`）に従っていることを確認する。
- `.claude/rules/docs-workflow.md`の「DDRを追加・変更したら」の指示どおり、DDR一覧の差分が
  同じコミットへ含まれることを確認する。
- **flow-id 5-1でorigin/mainを取り込んだ後**、本ブランチが追加・変更した全記述（SKILL.mdの新節・
  DDR本文）のflow-id番号が、取り込み後の実際の番号（5-5等）と整合しているかを再確認する
  （下記「issueの受け入れ条件との対応」(1)にも対応付ける）。

## issueの受け入れ条件との対応

| # | 受け入れ条件 | 対応状況 |
|---|---|---|
| (1) | `reports/…md` / `reports/…html`行の運用欄がflow-id 5-3（もしくは現在正しい番号）を指す | フェーズ2で確認済み（既にPR #144で5-4へ解消済み）。本計画では`docs-workflow.md`を変更しないため対応不要だが、**flow-id 5-1でのorigin/main取り込み後、本ブランチが追加した記述のflow-id番号が最新（取り込み後の正しい番号）と整合しているかを再確認する**（検証節参照） |
| (2) | 「片付け＝flow-id 5-1」と読める現行記述が他に残っていない | フェーズ2で確認済み（残っていない） |
| (3) | `.claude/docs/spec/` `.claude/docs/ddr/`の過去changelogを変更しない | 本計画のDDR追記は新規ファイルであり、既存changelogは変更しない（検証節のdiffで確認する） |
| (4) | 再発防止策の要否を検討し、結論を記録する | 本計画が対応（案Cの採用をSKILL.md追記＋DDRとして記録） |
