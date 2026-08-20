---
title: 【AIアセット反映】Gemini集計で得た教訓を反映する
type: plan
description: issue #97の作業中に踏んだ罠・気づいたルールの不備を、.claude/rules と .claude/skills へ反映するための個別反映計画
tags: [ai-asset, rules, skills, shell-script-style]
keywords: [shell-script-style, resolve-conflict, grep, sed, perl, 自動マージ, 数値整形, レビュー観点, REVIEW-POINTS]
---

# 個別反映計画: Gemini集計で得た教訓を反映する（issue #97 フェーズ4）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 全体作業計画: `plans/partitioned-forging-seahorse.md`
- 反映元: `worklog/20260820_..._push6.md`「ダメだったこと」、`HANDOFF.md`「判断を迷った内容」

**本ファイルには「これから何をするか」だけを書く。実施結果は
`reports/日付_partitioned-forging-seahorse_AIアセット反映.md` へ記録する。**

**`【設計反映】`（`plans/【設計反映】Gemini集計の仕様とDDRを反映する.md`）を完了・レビューして
から着手する。** 正史ドキュメントへの記録と運用ルールの改訂は、求められる判断の種類が違うため
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 目的

今回の作業で**実際に踏んだ**罠を、次に同じ場所で止まらないようAIアセットへ落とす。
「知っていれば防げた」ではなく「知っていたのに踏んだ」ものを優先する。

## 反映対象（flow-id 4-1 で洗い出した結果）

### 1. `.claude/rules/shell-script-style.md`

いずれも**今回実際に踏んだ**もの。既存の類似項目のすぐ近くへ入れる（重複した節を新設しない）。

| 追加する内容 | 入れる節 | 実例 |
|---|---|---|
| **数値の桁区切りは、行全体ではなく「数値と分かっている場所」へ適用する** | 「文字コード」節の後、`sed`/`awk` の項の近く | markdownの表を組み立てたあとに `sed -E ':a; s/([0-9])([0-9]{3})...'` を行全体へかけ、モデル名 `claude-3-5-sonnet-20241022` を `claude-3-5-sonnet-20,241,022` へ壊しかけた。整形は組み立て前（jq側の数値セル）で行う |
| **`grep` へ `-` で始まるパターンを渡すときは `--` を置く** | 「JSON操作」節の `jq --args` の `--` の項の直後 | `grep -cF '- 使用モデル:'` が `unknown option` で失敗した。`jq --args` と同じ理由（先頭のハイフンをオプションとして解釈する）なので、同じ場所へ並べる |
| **`perl -0pi -e "..."` / `sed "..."` をダブルクォートで囲まない** | 「文字コード」節の「文字列がもう1段解釈される」系の項の近く | 置換文字列に含めた `$(printf ...)` をシェルが先に展開し、意図しないコマンドが走った。小さな修正はEditツールで行う |

**判断が必要な点**: 3つ目は既存の「AIエージェント向け注記: ツールへ渡すコマンド文字列の中では、
バックスラッシュが1つに潰れることがある」と**原因が同じ**（文字列がもう1段解釈される）。
独立した項にせず、既存項へ1文追加するだけで足りる可能性がある。**実施時に既存の文面を読んでから
決める。**

### 2. `.claude/skills/resolve-conflict/SKILL.md`

| 追加する内容 | 入れる箇所 |
|---|---|
| **コンフリクトした範囲だけでなく、同じマージで「自動マージされて入った行」も確認する** | Step 4（類型別の解消）の類型Cの直後、または Step 5（検証）へ1項目 |

実例: 2回目の `main` マージで、`HANDOFF.md` の競合部分は解消したものの、**コンフリクトせずに
自動マージで入り込んだ別タスクのHTMLコメント**が残った。`HANDOFF.md` は「このブランチの現在の状態」
だけを表すべきファイルなので、これは誤りである。gitが競合と見なさない変更は `git status` にも
`git diff --check` にも出ないため、**マージ後に対象ファイルを通しで読む**必要がある。

**判断が必要な点**: これを Step 4（解消）と Step 5（検証）のどちらへ置くか。
「解消の一部」と読めば4、「解消後の確認」と読めば5。**Step 5 に置くほうが、類型に依存せず
必ず通る**ので第一候補とする。実施時に既存の記述の流れを見て決める。

### 3. `.claude/REVIEW-POINTS.md`（`.claude/` 配下のレビュー観点）

| 追加する観点（案） | 根拠 |
|---|---|
| **既存の出力を変えないはずのリファクタで、変えていないことを機械的に確認しているか**（旧実装との `diff`、旧テストの実行など。目視や「テストを足した」だけで済ませていないか） | 今回 `build_usage_report_body` の切り出しで実際に必要になった。「テストを足した」だけでは切り出し時点の劣化を検出できない |

**判断が必要な点**: この観点は `.claude/` 配下に限らずリポジトリ全体に効く。
**ルート直下の `REVIEW-POINTS.md` へ置くべきか**を実施時に判断する
（`.claude/rules/directory-structure.md`「一般的な観点ほど上位へ置き、下位で重複して書かない」）。

## 反映しないと判断したもの（記録）

| 内容 | 理由 |
|---|---|
| 「各statusを1件ずつ含むフィクスチャを最初に作る」 | 既に `.claude/rules/shell-script-style.md`「テスト」節の「合成フィクスチャのテストだけで完了としない」と、`plans/REVIEW-POINTS.md`「検証手順」で実質的に押さえられている。同じ趣旨の項目を増やすと、どれを読めばよいか分からなくなる |
| 「敵対的レビューの指摘は設計を変えることがある」 | `adversarial-review` スキルの目的そのものであり、追記しても情報が増えない |
| issue #94（`test_post_issue_create_notice.sh` の失敗） | 別issueの担当。本MRで直さない |

## やらないこと

- **spec / DDR への反映** → 別計画（`plans/【設計反映】Gemini集計の仕様とDDRを反映する.md`）で扱う。
- **コードの変更。** 本フェーズはAIアセット（ルール・スキル・観点表）のみを触る。
- **`AGENTS.md` / `CLAUDE.md` の変更。** 今回の教訓はいずれも詳細ルール側に属し、
  常時読み込まれる入口へ足すほどの一般性は無い。

## 検証手順

```bash
# 1. frontmatterインデックスが再生成できること（変更したmdのfrontmatterが妥当か）
bash .claude/scripts/src/extract-frontmatter.sh .

# 2. レビュー観点の収集が壊れていないこと（REVIEW-POINTS.mdを触った場合）
bash .claude/scripts/src/collect-review-points.sh .claude/hooks/lib/UsageTracking.sh
bash .claude/scripts/test/test_collect_review_points.sh   # passed=N failures=0

# 3. 単体テスト全体への巻き添えが無いこと
for t in .claude/scripts/test/test_*.sh; do echo "== $t"; bash "$t"; done

# 4. 差し込み位置の前後3行を目視で確認する（空行が2つ連続していないか・
#    次の見出しの直前に空行が1つあるか。.claude/rules/shell-script-style.md）
```

- 手順3では `test_post_issue_create_notice.sh` の `failures=1`（既存の失敗。issue #94）**だけ**が
  出ることを確認する。
- **手順4を省略しない。** 既存ドキュメントへ節を差し込む作業であり、
  `.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むときは、挿入位置の
  直前の節が『その節全体にかかる地の文』で終わっていないかを必ず確認する」が直接効く。

## 記録先

- 詳細な試行錯誤: `worklog/日付_partitioned-forging-seahorse_【AIアセット反映】Gemini集計で得た教訓を反映する_push<N>.md`
- 実施結果（正文）: `reports/日付_partitioned-forging-seahorse_AIアセット反映.md`
