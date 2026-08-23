---
title: issue #160 SKILL.mdのreferences分割 最終統括レポート
type: report
description: issue-mr-flow/SKILL.mdを本文＋references/7本へ分割し、参照タイミングを全体フロー表の参照列とSessionStart hookで機械化したブランチ全体の統括
tags: [issue-mr-flow, session-start, report]
keywords: [SKILL.md, references, 分割, 参照列, SessionStart, fail-open, ROW_RE, 統括レポート, skill-reference, 類型F]
---

# issue #160 SKILL.mdのreferences分割 最終統括レポート

- issue: #160 / PR: #161
- ブランチ: `claude/skill-split-references-z17fw4`（push 14回）
- 実施期間: 2026-08-23（全フェーズを同日で実施）

## 何を変えたか

- **`.claude/skills/issue-mr-flow/SKILL.md`（約1,100行）を、本文（入口・約190行）＋
  `references/` 7ファイルへ分割した。** 本文に残るのは全体フロー表・PR/MR担当・詳細ルールへの
  ポインタ・前提・旧節名の対応表で、詳細は `planning` / `deliverables` / `start-resume` /
  `review-loop` / `base-branch-followup` / `mcp-fallback` / `phase5-close` の7本が持つ。
  分割単位は行数ではなく**「いつ読むか」（同じflow-id群の実行前にまとめて開かれる単位）**。
- **全体フロー表へ「参照」列を新設し、各flow-idの実行前に開くファイルをこの列で機械的に
  決められるようにした。** 参照タイミングの正はこの列の1箇所だけで、hook側に対応表を持たない。
- **SessionStart hookが、`HANDOFF.md` の進捗表から現在地flow-idを解決し
  （`current_flow_id_to_reply`: 最後の `[x]`/`[-]` より後の最初の `[]`）、その行の参照列を
  読み出して「現在地 flow-id X-X の実行前に開く参照: …」の1行をフルパスで注入する。**
  解決に失敗したら参照行ごと出さないfail-open 4段（現在地不明／進捗セル不正／参照セル不正／
  参照 `—`）。`references/mcp-fallback.md` だけは参照列で指さず、MCP経路と判定したときに限り
  別行で注入する（CLIの有無はflow-idでなく実行環境で決まるため）。
- **旧節名からの導線**: 本文へ「旧節名→新しい場所の対応表」を置き、リポジトリ内の現在状態を
  説明する参照は移動先へ付け替えた（DDR本文・specの過去changelogは運用どおり書き換えない）。
- `references/*.md` は frontmatter `type: skill-reference` を新設して付与し、
  `.claude/rules/markdown-frontmatter.md` のtype表・`directory-structure.md` のバンドル
  リソース表・`index.md` へ反映した。配布資産の追加のため `.claude/VERSION` は 0.3.0 へ（MINOR）。
- **並行して進んだmainを2回取り込んだ**: PR #157（43ステップ化・`.gemini/` 変換同期の5-3挿入）と
  PR #154（manifest配布方式・`agent-common.md` 分離）。どちらも「配置の変更 vs 内容の変更」の
  コンフリクトで、解消手順を `resolve-conflict/SKILL.md` の**類型F**として一般化して追加した。

## なぜそうしたか

- **分割単位を「読むタイミング」にした**: サイズ均等分割は1ステップの実行に複数ファイルを
  またいで読む状態を作る。flow-idごとの読み込みバイト数を試算し、タイミング単位のほうが小さく
  なることを確認した（フェーズ2調査）。
- **参照列＋hook注入で「いつ読むか」を機械の側へ倒した**: 「必要になったら読む」は、compact
  要約後に「読んだ」という認識だけが残る失敗モード（issue #113と同型）を references/ の粒度で
  再生産する。hook側に対応表を持つ案は表との二重管理になり、行の繰り下げ（実際にissue #70で
  発生）へ追従できないため却下した。
- **fail-open**: DDR `i0113-01` が「誤った現在地の断定的注入」を理由に現在地要約の注入を
  却下した経緯と整合させ、解決に失敗したら出さない設計にした。
- 却下案5件の詳細は DDR `i0160-01` を参照。

## 検証結果

- 単体テスト: bash 18ファイル **passed=1259 failures=0**・perl 2ファイル OK
  （mainのPR #154取り込み後の最終実行。`test_session_start.sh` には現在地解決・参照注入・
  ROW_RE一致・実物 `HANDOFF.md` からの回帰の各テストを新設した）。
- 分割の同一性: 分割前のSKILL.md本文と「分割後の本文＋references/ 7本の結合」の見出し単位diffで、
  差分が見出しの再配置のみであることを確認（フェーズ3）。mainマージ後も同手法で等価性を確認。
- hookの注入行の実測: 604〜919バイト（組み立て済みの1行。プレフィックス
  「現在地 flow-id … の実行前に開く参照: 」約50バイトを含む）。
- `bash -n` 構文チェック・コンフリクトマーカー走査・`generate-ddr-list.sh --check`（79件最新）・
  `check-dist-coverage.sh`（414/414件、references/ 7本が配布対象に含まれることを確認）すべて通過。
- 敵対的レビューを各フェーズで自動実施: フェーズ2で2回（12件反映ほか）・フェーズ3で2回
  （19件対応ほか）・フェーズ4で2回（11件対応: 実測値訂正・VERSION増分例外の明文化・類型F追加等）。
  投稿した全スレッドへ返信済み（未返信 0）。

## spec・DDRへの反映先

- `.claude/docs/spec/issue-mr-workflow.md`: コンポーネント構成（SKILL.md本文＋references/ 7本）、
  「現在地flow-idと参照ファイルの注入（issue #160）」節（解決方法・fail-open 4段・フルパス化・
  表側の維持責任・mcp-fallback例外）、影響範囲changelog。
- `.claude/docs/spec/update-handoff-progress.md`: `ROW_RE` を session-start.sh へ同一リテラルで
  複製した制約と、一致をテストで表明する設計。
- `.claude/docs/spec/distribution-assets.md`: 非対話的セッションでのVERSION増分適用の例外を明文化。
- `.claude/docs/ddr/i0160-01-SKILL.mdの分割は読むタイミング単位で行い参照列とhookで機械的に注入する.md`:
  本決定の背景・却下案5件・i0113-01との関係。
- `.claude/docs/ddr/i0113-01…md`: frontmatter `note` へ「SKILL.mdは1,100行超」が分割前の値である
  旨を追記（本文は不変）。
- `.claude/skills/resolve-conflict/SKILL.md`: 類型F「配置の変更（分割・移動）vs 上流の内容変更」。
- `.claude/rules/markdown-frontmatter.md` / `directory-structure.md` / `index.md`:
  `skill-reference` type・references/ 実例の反映。

## 残課題

- **なし。** フェーズ2調査で別issue候補としていた2件（配布物への `index.jsonl` 混入・
  `install-to-project.sh` の破壊的既定）は、いずれもmainのPR #154が解消済みであることを
  取り込み時に確認した（`dist-layers.json` が `**/index.jsonl` をlocal層＝配布対象外に分類・
  配布先ディレクトリ引数は必須化されエラーで止まる）。
- 補足（制約の記録）: hookのgit bash（Windows実機）での動作確認は本環境（Linuxリモート）では
  実施できていない。判定ロジックはbash組み込みのみで、既存の `session-start.sh` の枠内の変更の
  ため、既知の環境差はspecの未決定事項としては追加していない。
