---
title: 実装結果 issue #113 SKILL.md再読み込み指示の注入
type: report
description: SessionStart hookへissue-mr-flow対象判定とSKILL.md再読み込み指示を追加した実装・検証の結果
tags: [report, session-start-hook, issue113]
keywords: [issue113, SessionStart, compact, SKILL.md, 対象判定, 結合確認, 単体テスト, 受け入れ条件, バイト数]
---

# 実装結果: issue #113 SKILL.md再読み込み指示の注入

全体作業計画: `plans/breezy-humming-lantern.md`
個別作業計画: `plans/【実装】【テスト】SKILL.md再読み込み指示の注入.md` /
`plans/【設計反映】session-start-hookの仕様とDDRへの反映.md`
実施日: 2026-08-20

## 結論

SessionStart hookが注入する追加コンテキストの**末尾**へ、issue-mr-flow対象ブランチと判定できる
場合にのみ「`.claude/skills/issue-mr-flow/SKILL.md` を読み直すこと」という指示を足した。
対象外のブランチ・`main` ブランチでは注入内容が1バイトも変わらない。

受け入れ条件はすべて満たしている（下記「受け入れ条件との対応」）。

## 調査結果（フェーズ2相当）

### 注入テキストの組み立て経路

`build_context` はCLI経路とMCP経路に分岐するが、ローカル情報を組み立てる
`build_work_context` は**両方から1回ずつ呼ばれる**。したがってここへ足せば、経路ごとの
二重管理にならず、内容も自動的に一致する。

### 対象ブランチの判定材料の比較

| 候補 | 取りこぼし | 取得コスト | 採否 |
|---|---|---|---|
| ブランチ名からissue番号を抽出（`get_issue_number_from_branch`） | ブランチ名が命名規則から外れている場合（`claude/<slug>` 等） | 文字列照合のみ | **採用** |
| ブランチ固有の作業ファイル（`get_branch_work_files`） | flow-id 1-3 直後（`plans/` 未作成） | `build_work_context` が既に取得済み。追加ゼロ | **採用** |
| `HANDOFF.md` の進捗表の有無 | リセット直後・ブランチ作成直後（**フローの最初と最後**） | ファイル読み取り1回 | 却下 |

上2つは取りこぼす場面が互いに補完的なため、**いずれか一方でも成り立てば対象**とする形にした。
`HANDOFF.md` の進捗表は、フローの最初と最後という最も取りこぼしてはいけない時点で空になり、
かつ表の書式変更に判定が引きずられるため採らなかった。

**このブランチ（`claude/skill-md-reload-prompt-jy5z5i`）自体が命名規則に一致しない**ため、
ブランチ名だけを材料にすると自分自身が対象外になる。取りこぼしは机上の懸念ではなく実在した。

### DDR 0032 との整合

| DDR 0032 の方針 | 今回の追加 |
|---|---|
| 注入内容は事前に決め、実行時に切り詰めない | 指示文の長さは有界（実測603バイト、根拠2件でも690バイト）。しきい値8000バイトの13分の1未満 |
| ファイルの中身は注入しない | 注入するのは「読め」という指示のみ。SKILL.mdの中身・要約は注入しない |
| 起動要因ごとに内容を分岐させない | 分岐なし。`.claude/settings.json` の matcher は無変更 |
| fail-open（追加項目の失敗が他の注入を妨げない） | 判定材料の取得失敗時は指示文を出さず、他の項目の注入を続ける |

## 実装内容

`.claude/hooks/session-start.sh` に純粋関数を2つ追加し、`build_work_context` から呼ぶ。

| 関数 | 役割 |
|---|---|
| `issue_mr_flow_branch_reason <issue番号> <作業ファイル一覧>` | 対象なら**判定根拠**を標準出力へ返す。対象外なら何も出さず終了コード1。外部コマンドを呼ばない |
| `format_skill_reload_instruction <判定根拠>` | 指示文（見出し＋本文）を組み立てる |

`build_work_context` は第1引数でブランチ名を受け取り、組み立ての最後に指示文を足す。
呼び出し元2箇所（CLI経路・MCP経路）は `"$branch"` を渡すだけの変更にとどめた。

指示文の要点は **「このセッションで既に読んでいる場合も読み直すこと」を明示している**点である。
SKILL.mdを読んだ事実は会話履歴に残るため、要約後のエージェントは「もう読んだ」という認識だけを
持ったまま、細部を失った理解で作業を続けてしまう。

実際に注入される指示文（判定根拠が1件の場合）:

```
## issue-mr-flowの手順（SKILL.md）を読み直すこと

このブランチはissue駆動MRワークフローの対象です（判定根拠: ブランチ名がissue命名規則に一致（issue #113））。作業を再開する前に
`.claude/skills/issue-mr-flow/SKILL.md`（唯一の実装フロー定義）を読み直してください。
**このセッションで既に読んでいる場合も読み直すこと**（compactの要約で、レビュー往復・
`commit`スキル経由の強制・`HANDOFF.md`の進捗更新といった手順が失われている可能性があります）。
```

## 検証結果

### 結合確認（使い捨てリポジトリでhook本体を実行）

`.claude/` `.mrworkflow.json` `HANDOFF.md` を複製した使い捨てリポジトリで、
`CLAUDE_PROJECT_DIR` を指定してhookを直接実行し、`additionalContext` を目視した。

| # | ブランチ状態 | 期待 | 結果 |
|---|---|---|---|
| 1 | `main` | 何も注入されない | 出力なし（`build_context` が exit 2） |
| 2 | `feature-113-skill-md-reload` | 指示あり（根拠＝命名規則一致） | 指示あり。根拠に `issue #113` |
| 3 | 命名規則外・作業ファイル無し | **指示なし**（既存挙動） | 指示なし。他の項目は従来どおり |
| 4 | 命名規則外・`plans/【実装】テスト.md` あり | 指示あり（根拠＝作業ファイル） | 指示あり。根拠に「作業ファイル」 |

### 単体テスト

`.claude/scripts/test/test_session_start.sh` を 35 → 51 ケースへ拡張した。

- `issue_mr_flow_branch_reason`: 両方空／issue番号のみ／作業ファイルのみ／両方 の4パターンと、
  対象外のときに何も出力しないこと、改行だけの入力の扱い。
- `format_skill_reload_instruction`: 見出し行・SKILL.mdのパス・判定根拠の埋め込み・
  「既に読んでいる場合も読み直すこと」・`compact` への言及・1000バイト未満であること。

全12テストスクリプトの結果（合計 649 ケース、`failures=0`）:

| スクリプト | 結果 |
|---|---|
| test_adversarial_review_count.sh | passed=22 failures=0 |
| test_check_base_conflicts.sh | passed=13 failures=0 |
| test_check_base_sync.sh | passed=55 failures=0 |
| test_cleanup_task.sh | passed=53 failures=0 |
| test_collect_review_points.sh | passed=17 failures=0 |
| test_extract_frontmatter.sh | passed=32 failures=0 |
| test_post_issue_create_notice.sh | passed=14 failures=0 |
| test_search_frontmatter.sh | passed=114 failures=0 |
| **test_session_start.sh** | **passed=51 failures=0**（35→51） |
| test_update_handoff_progress.sh | passed=45 failures=0 |
| test_usage_tracking.sh | passed=90 failures=0 |
| test_vcs_provider.sh | passed=143 failures=0 |

## 受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| issue-mr-flow対象ブランチでcompactが発生した場合、注入される追加コンテキストに「SKILL.mdを読み直すこと」という指示が含まれる | `build_work_context` の末尾で追加。matcherは `compact` を含むため、compact時にも同じ内容が注入される。結合確認 #2・#4 |
| 対象外（mainブランチ、軽微な変更で直接作業している場合）では既存の挙動を壊さない | `main` は `build_context` の exit 2 で従来どおり無注入（#1）。命名規則外・作業ファイル無しでも指示を足さない（#3）。単体テストでも「両方空なら終了コード1・出力なし」を固定 |
| 既存の単体テストが通り、必要なら新規テストケースを追加する | 既存35ケースはすべて通過。16ケースを追加し `passed=51 failures=0` |
| DDR 0032の設計方針（注入量のしきい値監視・切り詰めない）と矛盾しない | 上表「DDR 0032 との整合」。指示文は603バイトでしきい値8000バイトに対して十分小さく、切り詰めロジックも増やしていない |

## 反映結果（フェーズ4）

| 反映先 | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 「セッション開始時の自動コンテキスト注入」節へ判定・指示文の仕様、純粋関数一覧の更新、「影響範囲」へ issue #113 のエントリを追加 |
| `.claude/docs/ddr/0059-….md`（新規） | 判定材料の選び方・末尾へ置く理由・DDR 0032 との整合・却下案5件 |
| `.claude/docs/README.md` | DDR一覧へ 0059 を追加 |
| AIアセット（`.claude/rules/` `.claude/skills/`） | **反映なし**。踏んだ落とし穴（コミットhookの部分一致誤検知・`set -e` 下のコマンド置換・日本語文字列の比較）はいずれも `.claude/rules/shell-script-style.md` `.claude/rules/git-workflow.md` に既出のため |
| `.claude/settings.json` / `.gemini/settings.json` | **変更なし**。注入の内容だけを増やす変更で、matcherの変更を伴わない |

## 未解決・限界

- **人間のレビュー往復（flow-id 3-3/3-8・4-3/4-8）は実施できていない。** Claude Code on the web の
  非対話セッションのため、該当ループ範囲の進捗記号は `[]` のまま残している。
- **実際のcompact発生時の挙動は、この環境では確認していない。** 検証したのはhookの出力内容で
  あり、compactを起点にhookが発火することそのものは issue #57（DDR 0032）で確認済みの
  matcher設定に依存する。今回はmatcherを変更していないため、発火条件は変わらない。
- 対象判定は**ヒューリスティック**であり、「issue-mr-flowに乗せていないが `plans/` を作った」
  ブランチは対象と判定される。指示を1つ読ませるだけのコストなので、取りこぼす側より安全な
  方向へ倒している。判定根拠を指示文へ埋め込んであるため、誤判定は出力を見れば分かる。
