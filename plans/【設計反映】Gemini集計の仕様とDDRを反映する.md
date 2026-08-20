---
title: 【設計反映】Gemini集計の仕様とDDRを反映する
type: plan
description: issue #97の調査・実装で確定した設計判断を、.claude/docs/spec と .claude/docs/ddr へ反映するための個別反映計画
tags: [usage-report, gemini-cli, spec, ddr]
keywords: [issue-mr-workflow, 対応工数レポート, DDR, 未決定事項, 影響範囲, 畳み込み, ブランチ帰属, トークン列, rewindTo]
---

# 個別反映計画: Gemini集計の仕様とDDRを反映する（issue #97 フェーズ4）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 全体作業計画: `plans/partitioned-forging-seahorse.md`
- 反映元: `reports/20260820_partitioned-forging-seahorse_Geminiセッションログの調査.md`（フェーズ2）、
  `reports/20260820_partitioned-forging-seahorse_Gemini集計の実装.md`（フェーズ3）、
  `worklog/20260820_..._push6.md`

**本ファイルには「これから何をするか」だけを書く。実施結果は
`reports/日付_partitioned-forging-seahorse_設計反映.md` へ記録する**
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

**`【AIアセット反映】` は別ファイル**（`plans/【AIアセット反映】Gemini集計で得た教訓を反映する.md`）
とし、本計画の合意・実施が終わってから着手する（評価軸が混ざるため。
`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 目的

issue #97 で確定した設計判断を、**現在の正史**（`spec`）と**意思決定の記録**（`ddr`）へ落とす。
コードを読んだだけでは分からない「なぜそうしたか」「何を検討して捨てたか」を、この機会にしか
残せないため。

## 反映対象（flow-id 4-1 で洗い出した結果）

### 1. `.claude/docs/spec/issue-mr-workflow.md`

| 箇所 | 変更 |
|---|---|
| L839 付近「**Gemini CLIはミラーへの保存のみ対応し、対応工数の集計対象には含めない**（issue #23）」 | **記述を分割する。** メインセッションは集計対象になった（issue #97）が、**サブエージェントは引き続き保存のみ**である（設計判断I）。現行の文はこの2つを区別していないため、そのままでは誤りになる。`subagents/agent-*.jsonl` のglobが構造的にマッチしないという説明自体は、サブエージェント側の記述として残す |
| 「対応工数レポート」節（L647〜） | **Gemini CLI経路の小節を新設**する。内容は下表「specへ書く内容」 |
| 「未決定事項・懸念点」（L2554付近） | (a) **実機未検証の4点を追加**（`reports/…実装.md`「未検証として残る範囲」）。(b) 既存の「Gemini CLI側のサブエージェント探索の前提が実態と合っていない可能性（親と同じセッションIDで動作するとの報告）」は、フェーズ2の調査で**本体実装側から裏付けが取れた**ため、決定済みとして扱えるかを判断して書き換える |
| 「影響範囲」（L1270〜） | **issue #97 のエントリを新規追加**する。**既存エントリは1文字も変更しない**（point-in-timeの記録。`.claude/rules/docs-workflow.md`） |

**specへ書く内容**（「対応工数レポート」節の新小節）

- 差分の取り方: 毎回ファイル全体をid単位で畳み、**前回累計との差分**を取る。Claude Code経路の
  行カーソル方式は使わない。
- 前回累計の置き場所: `usage/state/gemini-totals/<sessionId>.json`（**ブランチ非依存**）。
- 消失検知: 1指標でも負なら `needsReset`。クランプ前（raw）の差分で早期リターンを判定する。
- レコード種別（メッセージ／`$set`／`$rewindTo`）の扱い。
- ツールの status の扱い（`error` のみエラー、`cancelled` は実行回数、未完了はどちらにも入れない）。
- トークン列の構成を**データで決める**こと（混在時は和集合）。
- 投稿ガードの拡張（`engine=gemini` のときだけ）。
- ブランチ帰属の限界。
- `_usage_append_push_index` をGemini経路で呼ばないこと。

### 2. `.claude/docs/ddr/` へのDDR新規作成（5本）

**採番は flow-id 4-6 の直前に `main` の最新を見て行う**（`main` が進むと衝突するため。
`.claude/skills/resolve-conflict/SKILL.md` 類型A）。以下は内容の割り当てのみを示す。

| 仮番号 | タイトル（案） | まとめる判断 |
|---|---|---|
| A | Gemini CLIの差分はファイル全体の畳み込みと前回累計の差分で取り前回累計はブランチ非依存に持つ | C・S・O・レビュー指摘1（ブランチ非依存）・`_usage_append_push_index` を呼ばない |
| B | Gemini CLIの`$rewindTo`は集計から外さない | D |
| C | 対応工数レポートのトークン列はengineではなくデータで決める | F・レビュー指摘6（混在時の和集合） |
| D | Gemini経路のブランチ帰属は断面時点のブランチとし限界を明示する | E |
| E | Gemini CLIのサブエージェントは保存のみとし集計しない | I |

- **A に C・S・O をまとめる理由**: この3つは「行カーソルが使えない」という1つの事実から導かれる
  一続きの判断であり、別々のDDRにすると相互参照だらけになる。**ブランチ非依存の置き場所も、
  同じ「二重計上を防ぐ」という目的の一部**なので同居させる。
- **却下案を必ず書く。** 各DDRには、フェーズ2で検討して採らなかった案（行カーソル方式、
  計上済みid集合を持つ案、`$rewindTo` で切り詰める案、`directories` からブランチを推定する案、
  engineで列を切り替える案、サブエージェントを集計する案）を残す。
- **DDR本文は書いたら変更しない。** frontmatterの `status` のみ後から更新可
  （`.claude/rules/markdown-frontmatter.md`）。

### 3. `.claude/docs/README.md`

DDR一覧へ、新規作成した5本を**採番後の番号で**追記する。

## やらないこと

- **AIアセット（`.claude/rules/` `.claude/skills/` `AGENTS.md`）への反映**
  → 別計画（`plans/【AIアセット反映】Gemini集計で得た教訓を反映する.md`）で扱う。
- **既存DDRの本文の変更**（`status` / `superseded_by` の更新を除く）。
- **spec の過去changelog（「影響範囲」の既存エントリ）の書き換え。** 追記のみ行う。
- **issue #105（テレメトリ）・#103・#94 に関する記述の追加。** 本MRの範囲外。
- **コードの変更。** フェーズ3で完了しており、本フェーズはドキュメントのみを触る。

## 検証手順

```bash
# 1. DDR番号の重複が無いこと（採番直後と、コミット直前の2回)
ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d   # 何も出なければ重複なし
bash .claude/scripts/src/check-base-conflicts.sh | jq '.hasDuplicateDdrNumber'

# 2. frontmatterインデックスが再生成できること（新規DDRのfrontmatterが妥当か）
bash .claude/scripts/src/extract-frontmatter.sh .

# 3. 新規DDRがインデックスに載り、type/description/keywords を持つこと
bash .claude/scripts/src/search-frontmatter.sh --type ddr --query gemini

# 4. README.mdのDDR一覧のリンク切れが無いこと
grep -oE '\(\./ddr/[0-9]{4}[^)]*\)' .claude/docs/README.md \
  | tr -d '()' | sed 's|^\./|.claude/docs/|' \
  | while read -r p; do [ -f "$p" ] || echo "リンク切れ: $p"; done

# 5. 単体テストへの巻き添えが無いこと（ドキュメントのみの変更だが念のため）
for t in .claude/scripts/test/test_*.sh; do echo "== $t"; bash "$t"; done
```

- 手順5では `test_post_issue_create_notice.sh` の `failures=1`（既存の失敗。issue #94）**だけ**が
  出ることを確認する。
- 手順1は**採番の直後にも実行する**。`main` が進んでいた場合はその場で繰り下げる。

## 記録先

- 詳細な試行錯誤: `worklog/日付_partitioned-forging-seahorse_【設計反映】Gemini集計の仕様とDDRを反映する_push<N>.md`
- 実施結果（正文）: `reports/日付_partitioned-forging-seahorse_設計反映.md`
