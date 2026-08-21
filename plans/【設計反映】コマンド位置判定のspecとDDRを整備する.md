---
title: 個別反映計画: コマンド位置判定のspecとDDRを整備する
type: plan
description: issue #53の実装内容を.claude/docs/spec/と.claude/docs/ddr/へ反映する個別反映計画
tags: [plan, 設計反映, hooks, issue-53]
keywords: [command-position, spec, DDR, i0000-09, note, generate-ddr-list, 部分一致, 誤検知]
---

# 個別反映計画: コマンド位置判定のspecとDDRを整備する

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- 全体作業計画: `plans/hook-command-position-detection.md`
- 実施結果の記録先: `reports/2026-08-21_hook-command-position-detection_設計反映結果.md`

> 本ファイルは**これから何をするか**のみを書く。実施した結果は上記 `reports/` へ記録する
> （`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

## 目的

判定が「部分一致」から「コマンド位置」へ変わったことを正史（`.claude/docs/`）へ反映する。
既存ドキュメントは**部分一致であることを前提に制約・回避策を書いている**ため、放置すると
正史が実装と食い違う。

## 反映対象と、それぞれ何をするか

洗い出しは `grep -rn '部分一致' --include='*.md' .` を起点に行い、gitignore対象の
`.claude/skills/apply-mr-workflow-to-project/assets/`（`sync-assets.sh` が生成するミラー）は
除外した。

### 新規作成

| ファイル | 内容 |
|---|---|
| `.claude/docs/spec/command-position.md` | **作成必須。** 3つのhookのコメントが既にこのパスを参照している。判定アルゴリズム（正規化 → コマンド位置トークン走査 → 保守的フォールバック）・公開関数のインターフェース・既知の制約・性能特性・要求bashバージョンを書く |

### 既存specの更新

| ファイル | 箇所 | 何をするか |
|---|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 1223行目付近「誤検知（pushしていないのに発火する）」 | **本文は書き換えず、追記で対応する。** この節は issue #23 / #47 の point-in-time な観測記録であり、上書きすると当時何が起きたかが読めなくなる（`.claude/rules/docs-workflow.md`）。issue #53 の変更エントリを新規に足し、「hookスクリプト側の判定がコマンド位置ベースになったため、地の文・クォート内・ヒアドキュメント本文では発火しなくなった」「`if` フィルタは変えていないため、`if` の照合規則の未解明（issue #47）はそのまま残る」を書く |
| 同上 | 1445行目付近「制約は『対応工数レポート』節と共通」 | `post-issue-create-notice.sh` も同じ検知ロジックを流用している旨の記述がある。**今回 `post-issue-create-notice.sh` は変更していない**ため、その非対称を明記する |
| `.claude/docs/spec/create-commit.md` | 17行目 | 「部分一致でブロックする」を現状（コマンド位置判定・読めない場合は部分一致へ縮退）へ更新する |
| `.claude/docs/spec/check-base-conflicts.md` | 233行目 | push検知hookの部分一致誤発火を前提にした記述。現状へ合わせる |

### DDR

| 識別子 | 何をするか |
|---|---|
| `i0053-01`（新規） | 判定の線引きを記録する。**採用**（正規化＋コマンド位置＋保守的フォールバック）と**却下案**（クォート除外のみ／完全なシェルパーサ／`if` フィルタの変更／インデックス走査による高速化）、および**あえて対策しない範囲**（意図的な文字列分割・変数展開・alias）を書く |
| `i0053-02`（新規・要否を判断） | 「静的に読めない実行体・長すぎる1行は部分一致へ縮退させる」という失敗の向きの決め方。`i0053-01` に収まるなら分けない |
| `i0000-09` | **本文は不変。** frontmatterの `note` へ「部分一致による誤検知は issue #53 でコマンド位置判定へ置き換えた」旨を1行で足す。`status` は変えない（コミットをスキル経由へ強制するという決定自体は有効なため） |

**本文を変更しないDDR**（既知の問題として当時の部分一致に言及しているが、その決定自体は
今回の変更で無効にならない）: `i0023-01` `i0046-01` `i0077-03` `i0088-01`。
`note` を足すかは、一覧を読む人が**開く前に知っておくべきか**で判断する（原則は足さない）。

### 生成物の再生成

- `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の
  DDR一覧の差分を同じコミットへ含める（一覧は生成物。手書きしない）。

## やらないこと

- **DDR本文の書き換え。** `i0000-09` を含め、一度マージしたDDRの本文は変更しない。
- **`.claude/docs/spec/issue-mr-workflow.md` の過去changelogエントリの書き換え。**
  ファイル移動でもDDR改番でもない今回は特に、過去の記録へ手を入れる理由が無い。
- **`post-issue-create-notice.sh` への判定適用。** issue #53 が名指ししておらず、スコープ外。
  必要なら別issueとして切り出す（この判断はspecへ書く）。
- **`.claude/VERSION` の更新。** 提案はするが、決定は人間が行う。

## 検証

- 追加・変更したmarkdownのfrontmatterが `.claude/rules/markdown-frontmatter.md` に沿うこと。
- `bash .claude/scripts/src/extract-frontmatter.sh .` が成功し、新規specがインデックスへ載ること。
- `generate-ddr-list.sh` の出力と `.claude/docs/README.md` に差分が残らないこと。
- hookのコメントが指す `.claude/docs/spec/command-position.md` が実在すること。
- `git diff <分岐点SHA> -- .claude/` の削除行が、意図した変更以外に出ていないこと。
