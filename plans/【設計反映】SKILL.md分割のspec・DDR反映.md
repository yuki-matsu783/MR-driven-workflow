---
title: 【設計反映】SKILL.md分割のspec・DDR反映
type: plan
description: issue #160 フェーズ4の個別反映計画。SKILL.md分割・参照列・SessionStart hook拡張の内容をspec 2本へ反映し、DDR i0160-01 を新規作成する
tags: [issue-mr-flow, plan, phase4]
keywords: [設計反映, spec, DDR, issue-mr-workflow, update-handoff-progress, SessionStart, 参照列, i0160-01, generate-ddr-list]
---

# 【設計反映】SKILL.md分割のspec・DDR反映（issue #160 / flow-id 4-1）

## 目的

フェーズ3で実施した「SKILL.mdの分割・全体フロー表の参照列・SessionStart hookの参照注入」を、
永続ドキュメント（`.claude/docs/spec/`・`.claude/docs/ddr/`）へ反映する。
`plans/` `worklog/` `reports/` は flow-id 5-4 で削除されるため、この反映が唯一の永続記録になる。

## 変更対象

| # | ファイル | 変更内容 |
|---|---|---|
| A | `.claude/docs/spec/issue-mr-workflow.md` | 「セッション開始時の自動コンテキスト注入」節の更新＋「影響範囲」への新規エントリ追記 |
| B | `.claude/docs/spec/update-handoff-progress.md` | `ROW_RE` が hook 側へ複製されている旨を「制約・設計判断」へ追記 |
| C | `.claude/docs/ddr/i0160-01-…md`（新規） | 分割単位・参照列・hook注入・複製の意思決定と却下案 |
| D | `.claude/docs/README.md` | `generate-ddr-list.sh` の再実行による生成差分（手書きしない） |

## 反映項目の詳細

### A. `issue-mr-workflow.md`「セッション開始時の自動コンテキスト注入」節

現在の状態を説明する節のみを更新する（過去issueのchangelogエントリは書き換えない）。

- **A-1**: 「issue-mr-flow対象ブランチでのSKILL.md再読み込み指示（issue #113）」項の直後へ、
  新項目「**現在地flow-idと参照ファイルの注入（issue #160）**」を追加する。内容:
  - `HANDOFF.md` の進捗表から現在地を「**最後の `[x]`/`[-]` の行より後に現れる、最初の `[]`**」で
    解決する（「最初の `[]`」方式は、非対話環境で人間レビュー行が `[]` のまま残ると永遠に
    そこを指し続けるため採らない）。
  - SKILL.md 全体フロー表の「参照」列を、ヘッダ行から列位置を求めて抽出する（対応表をhook側に
    持たない。表が唯一の正）。
  - **fail-open を4段で守る**: (1) 現在地が解決できない、(2) 進捗セルが `[x]`/`[]`/`[-]` の
    ちょうど1つでない（旧表記 `[x][x][]` の誤読防止）、(3) 抽出値が
    「`` `references/<名前>.md` `` の ` / ` 列挙」か「—」の形でない（セル内 `\|` による列ずれ防止）、
    (4) 参照が `—`——のいずれでも参照行を出さない。誤った名指しより、出ないほうが害が小さい。
  - 注入時は `.claude/skills/issue-mr-flow/` を前置した**リポジトリルート相対の完全パス**へ変換する。
  - 進捗表の行の正規表現 `ROW_RE` は `update-handoff-progress.sh` と**同一リテラルの複製**とし、
    一致を `test_session_start.sh` が表明する（`source` 共有はあちらの `set -euo pipefail` が
    hookのfail-open設計を壊すため不可）。
- **A-2**: 「構造とテスト（issue #57）」の純粋関数の列挙へ `current_flow_id_to_reply` /
  `refs_for_flow_id_to_reply` を追記する。
- **A-3**: 「SKILL.mdは1,100行超であり」という現状説明を分割後の姿
  （本文約180行＋`references/` 7ファイル、フロー定義全体では1,400行超）へ更新する。
  再読み込み指示の理由（compact要約で手順理解が失われる）は変わらないため理由部分は変えない。
- **A-4**: 「影響範囲」節へ `### issue #160（SKILL.mdのreferences分割と参照タイミングの機械化）`
  エントリを**新規追記**する（変更ファイル一覧・変更の要点。既存エントリは1文字も変更しない）。

### B. `update-handoff-progress.md`

「制約・設計判断」（相当節）へ1項を追記する: 進捗表の行判定の正規表現 `ROW_RE` は
`.claude/hooks/session-start.sh` に**同一リテラルで複製**されており、変更時は両方を同時に
直すこと・一致は `test_session_start.sh` が表明すること（issue #160）。

### C. DDR `i0160-01`（新規作成）

- ファイル名: `i0160-01-SKILL.mdの分割は読むタイミング単位で行い参照列とhookで機械的に注入する.md`
- 決定: (1) 分割単位は「いつ読むか」（サイズ4分割は却下。flow-idごとの読み込みバイト数が決め手）、
  (2) 参照タイミングは全体フロー表の「参照」列＋SessionStart hookの注入で機械化
  （本文ポインタのみ＝AI判断委ねは却下。issue #113・DDR i0057-01 と同型の劣化）、
  (3) DDR i0113-01 が同種の現在地解決を却下した件との整合（失敗時の損失が非対称）、
  (4) `ROW_RE` は複製＋一致テスト（`source` 共有・`hooks/lib/` 切り出しは却下）、
  (5) fail-open 設計（誤った名指しより出ないほうが害が小さい）。
- frontmatter は `markdown-frontmatter.md` の規約どおり（`title` は `i0160-01. <タイトル>`）。

### D. DDR一覧の再生成

`bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` に出た差分を
同じコミットへ含める（一覧は生成物。手書きしない）。

## やらないこと

- **DDR本文・specの過去changelogエントリの書き換え**（`.claude/rules/docs-workflow.md`）。
  specの更新は現在状態の節（「## 仕様」配下）と「影響範囲」への**新規エントリ追記**のみ。
- フロー自体の変更・他スキルの点検（issue #129 の担当）。
- フェーズ3で反映済みの項目の再変更（`markdown-frontmatter.md` の type 表・
  `directory-structure.md`・`index.md` は 3-6/3-9 で更新済み）。

## 検証手順

| # | 内容 | 合格条件 |
|---|---|---|
| 1 | `git diff` で spec の変更行を節ごとに突き合わせる | `issue-mr-workflow.md` の変更が「セッション開始時の自動コンテキスト注入」節と「影響範囲」の新規エントリのみ。既存の過去issueエントリの削除・変更行が0 |
| 2 | DDR識別子の形式 | ファイル名が `^i[0-9]{4}-[0-9]{2}-` に一致し、`title`・H1 と一致する |
| 3 | `generate-ddr-list.sh` 実行後の `git status` | 差分が `.claude/docs/README.md` のみ。`i0160-01` の行が一覧に現れる |
| 4 | 全テスト | 16本すべて `failures=0`（件数を記録する） |
| 5 | `search-frontmatter.sh --type ddr` | `i0160-01` が index.jsonl 経由で引ける |
| 6 | md/htmlの同期 | 本計画・反映レポートとも md と html を対で更新している |
