---
title: SKILL.md分割のspec・DDR反映 結果
type: report
description: issue #160 フェーズ4（flow-id 4-6）の反映結果。spec 2本の更新・DDR i0160-01の新規作成・i0113-01のnote・DDR一覧再生成・VERSION 0.3.0・hookコメント更新と、その検証結果
tags: [issue-mr-flow, report, phase4]
keywords: [設計反映, spec, DDR, i0160-01, issue-mr-workflow, update-handoff-progress, VERSION, generate-ddr-list, 検証]
---

# SKILL.md分割のspec・DDR反映 結果（issue #160 / flow-id 4-6）

計画 `plans/【設計反映】SKILL.md分割のspec・DDR反映.md` の A〜F をすべて実施した結果の正文。
実施の直前に main の PR #157（43ステップ化・`.gemini/` 生成物化・未返信スレッド管理）を
マージしたため、反映内容はマージ後の姿（flow-id 5-3〜5-7 の新番号・43ステップ）を前提に書いた。

## サマリ（結論の一覧）

- **A〜F 6項目をすべて実施した。** 検証8項目もすべて合格（下記）。
- A: `issue-mr-workflow.md` — コンポーネント構成ツリーへ `references/` 7本を追記（A-0）、
  「現在地flow-idと参照ファイルの注入（issue #160）」項を新設（A-1）、純粋関数の列挙へ
  2関数を追記（A-2）、「1,100行超」の現状説明と実測バイト値を更新（A-3）、影響範囲へ
  `### issue #160` エントリを新規追記（A-4）。
- B: `update-handoff-progress.md` — 「制約・設計判断」へ `ROW_RE` 複製の注意（B-1）、
  影響範囲へ `### issue #160` エントリ（B-2）。
- C: DDR `i0160-01` を新規作成（分割単位・参照列＋hook注入・fail-open・`ROW_RE` 複製の
  決定と却下案5件）。`i0113-01` の frontmatter `note` へ前提変化（1,100行→分割後）を追記
  （既存のflow-id繰り下げnoteと1行に統合。本文は不変）。
- D: `generate-ddr-list.sh` を実行。README の差分は計画どおり
  「`i0160-01` の新規行」「`i0113-01` の注記変化」の2つだけ。
- E: `.claude/VERSION` を `0.2.0` → `0.3.0`（MINOR）へ更新。判断は
  `HANDOFF.md`「判断を迷った内容」と A-4 の影響範囲エントリへ記録した。
- F: `session-start.sh` の「SKILL.md（1000行超）」コメントを分割後の姿へ更新（コメントのみ）。

## 実施した内容と結果

### A. `issue-mr-workflow.md`

- **A-0**: 「コンポーネント構成」ツリーの `.claude/skills/issue-mr-flow/` を
  `SKILL.md`（入口）＋ `references/`（7本）へ更新。SKILL.md の説明文へ本文＋参照資料の構成と
  「参照列が唯一の正」であることを追記し、DDR `i0160-01` への参照を付けた。
- **A-1**: 「issue-mr-flow対象ブランチでのSKILL.md再読み込み指示（issue #113）」の直後へ
  「**現在地flow-idと参照ファイルの注入（issue #160）**」を新設。内容は計画どおり
  （現在地の解決方式と「最初の `[]`」を採らない理由／参照列のヘッダ由来抽出／fail-open 4段／
  完全パス変換／表側の維持責任／`ROW_RE` 同一リテラル複製）に加え、マージで確定した
  「`references/mcp-fallback.md` は参照列で指さない」設計も同項へ書いた。
- **A-2**: 「構造とテスト（issue #57）」の純粋関数列挙へ `current_flow_id_to_reply` /
  `refs_for_flow_id_to_reply` を追記。
- **A-3**: 「SKILL.mdは1,100行超であり」→「分割後は本文約190行＋`references/` 7ファイル
  （フロー定義全体では1,400行超）。前提は変わらない」へ更新。実測バイト値は
  `format_skill_reload_instruction` の出力を `wc -c` で測り直した:
  **627バイト**（判定根拠1件・参照なし）〜**857バイト**（判定根拠2件＋参照3本の最大ケース）。
  測り方も本文へ添えた。
- **A-4**: 影響範囲の末尾（issue #70 エントリの後）へ `### issue #160` を新規追記
  （変更ファイル一覧・要点・VERSION更新の記録・新規DDRへのリンク）。既存エントリは変更していない。

### B. `update-handoff-progress.md`

- **B-1**: 「制約・設計判断」の末尾へ `ROW_RE` 複製の1項を追記（両方同時に直すこと・
  一致は `test_session_start.sh` が表明・`source` 共有を採らない理由）。
- **B-2**: 影響範囲へ `### issue #160（2026-08-23）ROW_REをSessionStart hookへ複製した` を
  新規追記（本スクリプト自身の挙動に変更が無いことを明記）。

### C. DDR

- **C-1**: `i0160-01-SKILL.mdの分割は読むタイミング単位で行い参照列とhookで機械的に注入する.md`
  を新規作成。決定5点（分割単位／参照列＋hook注入／fail-open 4段／`ROW_RE` 複製／
  mcp-fallback.md の例外）と却下案6件（サイズ4分割・AI判断委ね・hook側対応表・
  「最初の `[]`」方式・`source` 共有／`lib/` 切り出し・i0113-01 との整合）を記録した。
- **C-2**: `i0113-01` の `note` へ「前提の『SKILL.mdは1,100行超』はissue #160の分割前の値。
  現在は本文約190行＋references/ 7ファイル。詳細は i0160-01」を追記した。mainのマージで
  同キーに既にflow-id繰り下げの注記が入っていたため、**1行のまま連結**した（`note` は
  1行で書く規約。`.claude/rules/markdown-frontmatter.md`「DDRのnote」）。本文は変更していない。

### D〜F

- **D**: `generate-ddr-list.sh` 実行。差分は `i0160-01` 新規行と `i0113-01` 注記変化の2つのみ
  （検証#4で `--check` 終了コード0も確認）。
- **E**: `.claude/VERSION` `0.2.0`→`0.3.0`。
- **F**: `session-start.sh` の該当コメントを「SKILL.md（issue #160の分割後は本文＋references/
  7ファイルで構成されるフロー定義全体）」へ更新。`bash -n` 合格・全テスト合格（検証#5）。

## 検証結果

分岐点は `base="$(git merge-base origin/main HEAD)"`（= mainのPR #157マージ後の断面 585a6b3）。

| # | 内容 | 結果 |
|---|---|---|
| 1 | specの変更ハンクの節対応付け | **合格**。`git diff "$base"` のハンクは、今回分（コンポーネント構成 @51/@84・自動コンテキスト注入 @843/@856/@879・影響範囲エントリ @3120）と、フェーズ3由来の参照付け替え（マージ解消で再適用したもの）のみ。マージ解消がフェーズ3の変更と同一であることは、マージ前後の差分行の突き合わせで確認した（相違は main 自身が行ったflow-id繰り下げ2箇所だけ） |
| 2 | `.claude/` 全体の巻き添え | **合格**。`git diff "$base" --stat -- .claude/` は計画の変更対象＋フェーズ3までの変更分のみ。`.claude/docs/ddr/` の差分は `i0113-01` の note 1行（+新規 `i0160-01`）のみ |
| 3 | DDR識別子の形式 | **合格**。ファイル名 `i0160-01-…` / frontmatter `title: i0160-01. …` / 本文H1 `# i0160-01. …` が一致 |
| 4 | DDR一覧の再生成 | **合格**。`generate-ddr-list.sh --check` 終了コード0。README差分に `i0160-01` の行と `i0113-01` の注記変化 |
| 5 | 全テスト | **合格**。17本すべて `failures=0`（passed 合計 1132。マージ直後に全17本、反映後に再実行して確認。再実行時に、マージ解消時の `HANDOFF.md` 編集で `## 次にやること` 見出しを誤って落としていたことを実データ回帰テストが2件の失敗として検出し、修正した） |
| 6 | frontmatter検索 | **合格**。`search-frontmatter.sh --type ddr --text i0160 --format path` が `i0160-01` を1件返す |
| 7 | md/htmlの同期（機械） | **合格**。本レポート・計画とも md の `##` 一覧と html の `<h2>` 一覧が一致（目次見出しは `class="toctitle"` で除外）。`<!-- ここに書く` 残存0。外部URL参照0 |
| 8 | VERSIONの形式 | **合格**。`0.3.0` の1行のみ |

## 確かめられなかったこと

- `.gemini/` 側での references/ の見え方の実機確認は**不要になった**。mainのissue #70で
  `.gemini/` はリンクではなく `sync-gemini-assets.sh` による変換生成物になり、flow-id 5-3 の
  同期で `references/` もコピーされる（コピー対象であることは同スクリプトの列挙仕様から明らか。
  実際の同期は flow-id 5-3 で実行し、そこで差分として確認できる）。

## 設計への反映

反映しきれず次のissueへ回したものは**無い**（本レポート自体が設計反映の結果）。
別issue候補として引き継ぐもの（起票はユーザー判断）:

- 配布物への `index.jsonl` 混入（`sync-assets.sh` が生成物を配布対象に含めてしまう）。
- `install-to-project.sh` の破壊的既定（引数省略時にカレントへ展開する）。

## 想定と異なった点

- **計画時点と反映時点でフローの番号体系が変わった。** 計画の直後に main の PR #157 が
  43ステップ化（新5-3の挿入・5-4〜5-7への繰り下げ）を持ち込んだため、計画に書いた旧番号
  （統括=5-3・片付け=5-4 等）を新番号へ読み替えて反映した（計画md/html側の番号も更新済み）。
- **C-2 の `note` は「新規追加」ではなく「既存noteへの連結」になった。** main が同じキーへ
  flow-id繰り下げの注記を先に入れていたため（上記）。
- **A-3 の実測値は計画の想定（603/690バイト）から627〜857バイトへ変わった。** issue #160 の
  参照行そのものが指示文を伸ばすため。最大ケース（参照3本）を含めて測り直した。
