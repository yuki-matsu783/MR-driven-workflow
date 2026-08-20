---
title: Gemini集計の設計反映の結果（issue #97 フェーズ4・設計反映）
type: report
description: issue #97の設計判断をspec・DDR・rulesへ反映した結果と、DDR 0022のstatusを更新しないと判断した理由
tags: [usage-report, gemini-cli, spec, ddr]
keywords: [DDR0050, DDR0054, superseded, 影響範囲, 未決定事項, directory-structure, 採番, quotepath, 検証]
---

# 設計反映の結果: Gemini集計の仕様とDDR（issue #97 フェーズ4）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 個別反映計画: `plans/【設計反映】Gemini集計の仕様とDDRを反映する.md`

## 結論

**計画した反映対象をすべて反映し、検証手順の全項目が通った。** 新設したDDRは5本（0050〜0054）。
**DDR 0022 には `status: superseded` を付けないと判断した**（理由は下記）。

## 反映した内容

### 新規（DDR 5本）

| 番号 | タイトル | 対応する設計判断 |
|---|---|---|
| 0050 | Gemini集計の差分はファイル全体の畳み込みと前回累計の差分で取る | C（差分の取り方）・S（消失検知）・O（行カーソルを使わない）＋前回累計のブランチ非依存化＋`_usage_append_push_index` を呼ばない |
| 0051 | Gemini集計はrewindToを読み飛ばしメッセージを削らない | D（`$rewindTo`の扱い） |
| 0052 | 対応工数レポートのトークン列はengineではなくデータで決める | F（トークン列）＋混在時の和集合 |
| 0053 | Gemini経路のブランチ帰属は断面時点のブランチとし限界を明示する | E（ブランチ帰属） |
| 0054 | Gemini CLIのサブエージェントは保存のみとし集計しない | I（サブエージェント） |

**採番は 0050〜0054。** `origin/main` とローカルの最大がいずれも `0049` であることを確認して決めた。

**各DDRに却下案を書いた**（計画の指示どおり）。行カーソル方式・計上済みid集合・ブランチ別の
前回累計・`session-cursors` への相乗り・切り詰めへの個別対応・`$rewindTo` での切り詰め・
`directories` からのブランチ推定・engineでの列切り替え・常に6列・engineごとの状態ファイル分割・
モデル名からのengine推定・サブエージェントの集計・`agentId` を使った親からの集計、など。

### 更新

| ファイル | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 「エンジン判定」節のGemini記述を**メイン／サブエージェントで分割**／「コンポーネント」へGemini経路の分岐・新設関数5本・`build_usage_report_body` を追記／**「Gemini CLI経路（issue #97）」小節を新設**／「未決定事項・懸念点」へ実機未検証の4点を追加し、サブエージェント探索の既存の懸念へ本体実装からの裏付けを追記／「影響範囲」へ issue #97 のエントリを**追記**（既存エントリは1文字も変更していない） |
| `.claude/rules/directory-structure.md` | `usage/` の内訳へ `usage/state/gemini-totals/<sessionId>.json` を追加。既存の `session-cursors` / `push-index.jsonl` にも「Claude Code経路のみ」と明記 |
| `.claude/hooks/lib/UsageTracking.sh` | `_usage_sync_session_logs` のコメントを訂正（**コメントのみ。挙動は変えていない**） |
| `.claude/docs/README.md` | DDR一覧へ0050〜0054を追加。0022の行へ参照注記を添えた |

## DDR 0022 に `status: superseded` を付けないと判断した理由

計画では「付けるかを判断し、いずれでも理由を残す」としていた。**付けない**を選んだ。

- **0022の主題は「push断面の全文コピーをやめ行番号インデックスで表現する」ことであり、
  Gemini CLIの集計対象外はその一部（「Gemini CLI対応の扱い」節）にすぎない。**
  issue #97 が覆したのはさらにその一部（メインセッション分）だけで、
  サブエージェントを集計しない部分は**引き続き有効**である。
- `.claude/rules/markdown-frontmatter.md` の `superseded` は「後続のDDRによって置き換えられた」
  DDRに付けるもので、**DDR全体が無効になっていない今回は過剰**である。付けてしまうと、
  0022の主題（push断面のインデックス化）まで無効になったように読める。
- 代わりに次の2つで、0022 を先に見た読み手が issue #97 の変更へ辿り着けるようにした。
  1. **DDR 0054 の本文から0022を参照し**、どの部分が生きていてどこが置き換わったかを明示した
     （「却下した案」にも「0022に `superseded` を付ける」案とその却下理由を記載）。
  2. **`.claude/docs/README.md` のDDR一覧の0022の行へ注記を添えた**
     （「うち『Gemini CLI対応の扱い』は、issue #97でメインセッションのみ集計対象へ変更された。
     サブエージェントを集計しない部分は引き続き有効。詳細は0054」）。
- **0022の本文・`description` は変更していない。**

## 検証結果

| # | 手順 | 結果 |
|---|---|---|
| 1 | DDR番号の重複（採番直後・ローカル／`origin/main` との突き合わせ） | 重複なし |
| 2 | frontmatterインデックスの再生成 | `files=103 built=15 reused=88 failed=0` |
| 3 | 新規DDRがインデックスに載ること | `--type ddr --text gemini` で0050〜0054がすべてヒット（`matched=8`） |
| 4 | README.mdのDDR一覧のリンク切れ | リンク切れ0件。**マッチ件数50**（0件＝空振りでないことを確認） |
| 5 | 差し込み位置の前後の目視確認 | 空行の連続・見出しのくっつきなし |
| 6 | 単体テスト全体（11ファイル） | `test_post_issue_create_notice.sh` の `failures=1`（既存。issue #94）のみ。`test_usage_tracking.sh` は `passed=81 failures=0` を維持 |
| 7 | DDR番号の重複（コミット直後・`check-base-conflicts.sh`） | コミット後に実行（下記） |

## 計画の検証手順の誤りを2つ直した

**実行してみて初めて分かった**もので、いずれも「検証したつもりになる」型である。

1. **採番チェックが既存DDRを全件「重複」と報告した。** 2段階の誤りがあった。
   (a) 番号だけを集めて `uniq -d` していたため、ローカルとmainの両方にある既存DDRがすべて
   2回現れた。ファイル名で先に `sort -u` する必要がある。
   (b) それを直しても全件重複のままだった。原因は **`git ls-tree` が非ASCIIパスを
   8進エスケープして返す**こと（`ls` の出力と一致しない）。`-c core.quotepath=false` で解決。
   これは `.claude/rules/shell-script-style.md` に既出の罠である。
2. **`search-frontmatter.sh --query` は存在しなかった**（正しくは `--text`）。

**検証コマンドは「異常が無いとき何も出ない」形が多く、正常系だけ試すと動作を誤認する。**
今回は逆方向（大量に出る）だったので気づけたが、常に0件になる誤りだったら気づけなかった。
`grep -cE` でマッチ件数を出す形（手順4）を入れておいたのは、この意味で正しかった。
