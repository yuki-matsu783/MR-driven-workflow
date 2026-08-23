---
title: 【設計反映】SKILL.md分割のspec・DDR反映
type: plan
description: issue #160 フェーズ4の個別反映計画。SKILL.md分割・参照列・SessionStart hook拡張の内容をspec 2本へ反映し、DDR i0160-01 の新規作成・i0113-01のnote・VERSION更新を行う
tags: [issue-mr-flow, plan, phase4]
keywords: [設計反映, spec, DDR, issue-mr-workflow, update-handoff-progress, SessionStart, 参照列, i0160-01, generate-ddr-list, VERSION]
---

# 【設計反映】SKILL.md分割のspec・DDR反映（issue #160 / flow-id 4-1）

## 目的

フェーズ3で実施した「SKILL.mdの分割・全体フロー表の参照列・SessionStart hookの参照注入」を、
永続ドキュメント（`.claude/docs/spec/`・`.claude/docs/ddr/`）へ反映する。
`plans/` `worklog/` `reports/` は flow-id 5-5 で削除されるため、この反映が唯一の永続記録になる。

## 反映元と洗い出しの対応表

反映元は次の3つ（いずれも本ブランチ上のファイル）。

- `reports/20260823_split-issue-mr-flow-skill-into-references_作業.md`（フェーズ3の結果の正文）
- `reports/20260823_split-issue-mr-flow-skill-into-references_調査.md`（フェーズ2の結果の正文）
- `plans/split-issue-mr-flow-skill-into-references.md`（全体作業計画「フェーズ4〈反映〉」節）

そこから洗い出した項目と本計画での扱い:

| 洗い出した項目 | 扱い |
|---|---|
| SKILL.md の構成（本文＋references/）のspec反映 | **反映する**（A-0） |
| SessionStart hook の注入項目追加のspec反映 | **反映する**（A-1〜A-3） |
| 分割単位・機械化・複製の意思決定の記録 | **反映する**（C: DDR `i0160-01`） |
| `ROW_RE` 複製の注意の `update-handoff-progress.md` への反映 | **反映する**（B） |
| `.claude/VERSION` の更新（`distribution-assets.md` が flow-id 4-6 と定める） | **反映する**（E） |
| DDR `i0113-01` の前提変化（1,100行→分割後） | **反映する**（C-2: frontmatter `note`） |
| `markdown-frontmatter.md` type表・`directory-structure.md`・`index.md` | **済み**（フェーズ3の 3-6/3-9 で反映済み。再変更しない） |
| `.gemini/` 側のリンク動作 | **追加作業なしと結論**（`setup-gemini-links.sh` は `skills` を**ディレクトリ単位**でリンクするため、`references/` はリンク越しに自動で見える。Windows実機での動作確認だけが残り、これは本環境では不可能なので `HANDOFF.md`「判断を迷った内容」へ記録して引き継ぐ） |
| 配布物への `index.jsonl` 混入・`install-to-project.sh` の破壊的既定 | **別issue候補として引き継ぐ**（本issueのスコープ外。起票の要否はユーザー判断のため、flow-id 5-4 の統括レポートと `HANDOFF.md` へ明記して委ねる。このセッションでは起票しない） |

## 変更対象

| # | ファイル | 変更内容 |
|---|---|---|
| A | `.claude/docs/spec/issue-mr-workflow.md` | 「コンポーネント構成」ツリー・「セッション開始時の自動コンテキスト注入」節の更新＋「影響範囲」への新規エントリ追記 |
| B | `.claude/docs/spec/update-handoff-progress.md` | `ROW_RE` 複製の注意を「制約・設計判断」へ、issue #160 エントリを「影響範囲」へ追記 |
| C | `.claude/docs/ddr/i0160-01-…md`（新規）＋ `i0113-01` の frontmatter `note` | 意思決定の記録と、前提が変わった既存DDRへの導線 |
| D | `.claude/docs/README.md` | `generate-ddr-list.sh` の再実行による生成差分（手書きしない） |
| E | `.claude/VERSION` | `0.2.0` → `0.3.0`（MINOR。理由は下記） |
| F | `.claude/hooks/session-start.sh` | コメント内の陳腐化した現状説明（「SKILL.md（1000行超）」）の更新 |

## 反映項目の詳細

### A. `issue-mr-workflow.md`

現在の状態を説明する節のみを更新する（過去issueのchangelogエントリは書き換えない）。

- **A-0**: 「コンポーネント構成」のツリーで `.claude/skills/issue-mr-flow/` 配下を
  `SKILL.md`（入口: 全体フロー表・参照列・対応表）＋ `references/`（詳細7ファイル）の構成へ更新する。
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
  - **表側の維持責任**: 列見出し `参照` とヘッダ行の存在がhookの前提であり、変えると注入は
    fail-open で**無言に**止まる。flow-id の行を追加するときは参照列を必ず埋める
    （空欄ではなく `—`）。実SKILL.md全42行の実データ回帰テストがこれを守っている。
  - 進捗表の行の正規表現 `ROW_RE` は `update-handoff-progress.sh` と**同一リテラルの複製**とし、
    一致を `test_session_start.sh` が表明する（`source` 共有はあちらの `set -euo pipefail` が
    hookのfail-open設計を壊すため不可）。
- **A-2**: 「構造とテスト（issue #57）」の純粋関数の列挙へ `current_flow_id_to_reply` /
  `refs_for_flow_id_to_reply` を追記する。
- **A-3**: 「SKILL.mdは1,100行超であり」という現状説明を分割後の姿
  （本文約190行＋`references/` 7ファイル、フロー定義全体では1,400行超）へ更新する。
  再読み込み指示の理由（compact要約で手順理解が失われる）は変わらないため理由部分は変えない。
  「実測603バイト・690バイト」の数値は**参照行を含めた実測値へ更新**し、測り方
  （`format_skill_reload_instruction` の出力を `wc -c` で測る）を添える。
- **A-4**: 「影響範囲」節へ `### issue #160（SKILL.mdのreferences分割と参照タイミングの機械化）`
  エントリを**新規追記**する（変更ファイル一覧・変更の要点・VERSION更新の記録。
  既存エントリは1文字も変更しない）。

### B. `update-handoff-progress.md`

- **B-1**: 「制約・設計判断」へ1項追記: 進捗表の行判定の正規表現 `ROW_RE` は
  `.claude/hooks/session-start.sh` に**同一リテラルで複製**されており、変更時は両方を同時に
  直すこと・一致は `test_session_start.sh` が表明すること（issue #160）。
- **B-2**: 「影響範囲」へ `### issue #160` エントリを新規追記する（A-4 と対称にする。
  このspecだけを読む人が `ROW_RE` 複製の経緯を辿れるようにするため）。

### C. DDR

- **C-1**: `i0160-01-SKILL.mdの分割は読むタイミング単位で行い参照列とhookで機械的に注入する.md`
  を新規作成する。決定: (1) 分割単位は「いつ読むか」（サイズ4分割は却下。flow-idごとの
  読み込みバイト数が決め手）、(2) 参照タイミングは全体フロー表の「参照」列＋SessionStart hookの
  注入で機械化（本文ポインタのみ＝AI判断委ねは却下。issue #113・DDR i0057-01 と同型の劣化）、
  (3) DDR i0113-01 が同種の現在地解決を却下した件との整合（失敗時の損失が非対称）、
  (4) `ROW_RE` は複製＋一致テスト（`source` 共有・`hooks/lib/` 切り出しは却下）、
  (5) fail-open 設計（誤った名指しより出ないほうが害が小さい）。
  frontmatter は `markdown-frontmatter.md` の規約どおり（`title` は `i0160-01. <タイトル>`）。
- **C-2**: `i0113-01` の frontmatter へ `note` を1行追加する（例: 「本文が前提とする
  『SKILL.mdは1,100行超』はissue #160の分割前の値。現在は本文約190行＋references/ 7ファイル。
  詳細は i0160-01」）。本文は変更しない（frontmatterのみの更新は
  `markdown-frontmatter.md`「DDRのnote」が認める類型）。

### D. DDR一覧の再生成

`bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` に出た差分を
同じコミットへ含める（一覧は生成物。手書きしない）。差分には `i0160-01` の新規行と、
`i0113-01` の行への `note` 由来の注記の**2つ**が現れるはずである。

### E. `.claude/VERSION`

`0.2.0` → `0.3.0`（MINOR）。`distribution-assets.md` が更新タイミングを flow-id 4-6 と定めており、
issue #160 は配布対象アセットへ `references/` 7ファイルを**追加**し（`sync-assets.sh` は
`.claude/skills/*` を `cp -R` する）、hook・スクリプトも変更しているため「資産の追加」= MINOR に
当たる。増分の決定は本来人間が行うが、非対話環境のため **MINOR を適用したうえで
`HANDOFF.md`「判断を迷った内容」へ記録し、レビューで否認されたら戻す**（据え置きではないので
据え置き記録は不要。適用の事実は A-4 の影響範囲エントリへも書く）。

### F. `session-start.sh` のコメント更新

`format_skill_reload_instruction` 付近のコメントにある「SKILL.md（1000行超）」という現状説明を
分割後の姿へ更新する（コードの動作は変えない。コメントのみ）。

## やらないこと

- **DDR本文・specの過去changelogエントリの書き換え**（`.claude/rules/docs-workflow.md`）。
  specの更新は現在状態の節（「## 仕様」配下）と「影響範囲」への**新規エントリ追記**のみ。
  DDR `i0113-01` は frontmatter の `note` のみ（本文不変）。
- フロー自体の変更・他スキルの点検（issue #129 の担当）。
- フェーズ3で反映済みの項目の再変更（`markdown-frontmatter.md` の type 表・
  `directory-structure.md`・`index.md` は 3-6/3-9 で更新済み）。
- 別issue候補（配布物への `index.jsonl` 混入・`install-to-project.sh` の破壊的既定）の**起票**
  （ユーザー判断に委ねる。統括レポートと `HANDOFF.md` へ引き継ぎを明記する）。

## 検証手順

分岐点は `base="$(git merge-base origin/main HEAD)"` で固定する（作業ツリー比較の引数なし
`git diff` は、コミットした瞬間に保証が失効するため使わない）。

| # | 内容 | 合格条件（実行するコマンド） |
|---|---|---|
| 1 | specの変更行の節対応付け | `git diff "$base" -- .claude/docs/spec/issue-mr-workflow.md` の変更ハンクがすべて「コンポーネント構成」「セッション開始時の自動コンテキスト注入」「影響範囲の issue #160 エントリ（新規追記）」のいずれかに属する。既存の過去issueエントリの削除・変更行が0（ハンクごとに所属節を列挙して確認する） |
| 2 | `.claude/` 全体の巻き添え確認 | `git diff "$base" --stat -- .claude/` の変更ファイル一覧が本計画の変更対象（＋フェーズ3までの変更分）と一致する。`git diff "$base" -- .claude/docs/ddr/` の差分が「`i0160-01` の新規追加」と「`i0113-01` の frontmatter `note` 行」のみ |
| 3 | DDR識別子の形式 | ファイル名が `^i[0-9]{4}-[0-9]{2}-` に一致し、frontmatter `title`・本文H1 と識別子が一致する |
| 4 | DDR一覧の再生成 | `bash .claude/scripts/src/generate-ddr-list.sh --check` の終了コードが**0**（＝コミット内容が再生成結果と一致）。`git diff "$base" -- .claude/docs/README.md` に `i0160-01` の行と `i0113-01` の注記変化が現れる |
| 5 | 全テスト | 16本すべて `failures=0`（合計 passed 件数を記録する） |
| 6 | frontmatter検索 | `bash .claude/scripts/src/search-frontmatter.sh --type ddr --query i0160` 相当で `i0160-01` が引ける |
| 7 | md/htmlの同期（機械） | 本計画・反映レポートとも: md の `##` 見出し一覧と html の `<h2>` 一覧が一致（`grep '^## ' <md>` と `grep -o '<h2>[^<]*</h2>' <html>` の突き合わせ）。`grep -c '<!-- ここに書く' <html>` が 0。`grep -nE "(src|href)=['\"]?(https?:)?//" <html>` が 0件 |
| 8 | VERSIONの形式 | `.claude/VERSION` が `0.3.0` の1行のみ（SemVer） |
