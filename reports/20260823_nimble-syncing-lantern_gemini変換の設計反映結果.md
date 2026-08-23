---
title: gemini変換の設計反映結果
type: report
description: issue #70 のフェーズ4〈反映〉2本目、【設計反映】の実施結果。sync-gemini-assets.mdの新規作成・DDR2本の追加・i0000-13のsuperseded化・繰り下げ漏れの解消と、その検証結果
tags: [report, spec, ddr, issue-70]
keywords: [sync-gemini-assets, i0070-01, i0070-02, i0000-13, setup-gemini-links, 繰り下げ, REVIEW-POINTS, 検出力, 別issue]
---

# 反映結果: gemini変換の仕様化とDDR整備（`【設計反映】`）

個別反映計画: `plans/【設計反映】gemini変換の仕様化とDDR整備.md`
全体作業計画: `plans/nimble-syncing-lantern.md`（issue #70 / PR #157 / flow-id 4-6・2周目）

## サマリ（結論の一覧）

| # | やったこと | 結果 | 根拠の性質 |
|---|---|---|---|
| 1 | `.claude/docs/spec/sync-gemini-assets.md` の新規作成 | **作成した**。スクリプトの冒頭が「仕様」として指していたパスの実体が埋まった | スクリプト本体の読解 |
| 2 | DDR `i0070-01`（`.gemini/` を変換生成物にする）の作成 | **作成した**。却下案5件を明記 | 判断の記録 |
| 3 | DDR `i0070-02`（返信漏れは機構で塞ぐ）の作成 | **作成した**。却下案5件を明記 | 判断の記録 |
| 4 | DDR `i0000-13` の無効化 | **frontmatterのみ** `status: superseded` / `superseded_by: "i0070-01"`。**本文は1行も変えていない** | `git diff` の削除行4件がすべて `note:` |
| 5 | 削除済み `setup-gemini-links.sh` への参照 | **3箇所とも解消**（`README.md` / `index.md` / `directory-structure.md`）。残り1件は「以前はこうだった」という経緯の説明 | 全文検索・件数付き |
| 6 | `flow-id 5-4` の繰り下げ漏れ | **`reports/REVIEW-POINTS.md` の1件を解消**。残る36件はすべて**新しい 5-4（統括レポート）を正しく指す記述**か、DDR本文・changelog・タスク単位ファイル | 全文検索・所属見出しの確認 |
| 7 | `.claude/docs/spec/issue-mr-workflow.md` | 「Gemini CLIのhook登録」節を生成物前提へ書き直し、**用語変換規則の正を1箇所へ寄せた**。issue #57 の未決定事項を「決定済み事項」へ移し、`### issue #70` のchangelogを追加 | — |
| 8 | 重複していた単体テスト2件 | **独立に落ちるようにした**。除外を外すと `.gemini` 側だけが落ち `build` 側は通ることを確認 | 実測（意図的な破壊） |
| 9 | `.gitignore` の存在しないDDR名（`i36-01`） | **直していない**。issue #70 の成果と無関係なので**別issueへの切り出しを提案する**（AIから起票はしない） | 計画どおり |

## 実施条件

- 実行環境: Claude Code on the web のリモート実行環境（Linux）。`gh`/`glab` CLI 不在（MCP経路）。
- 実施日: 2026-08-23
- 分岐点: `805ab5f`（`git merge-base origin/main HEAD`）

## 実施した内容と結果

### 1. `.claude/docs/spec/sync-gemini-assets.md`（新規）

`sync-gemini-assets.sh` の冒頭は `# 仕様: .claude/docs/spec/sync-gemini-assets.md` と書いて
いたが、**そのファイルは存在しなかった**。スクリプト本体を読んで仕様として書き起こした。

含めたもの: 3モード（write / `--check` / `--dry-run`）＋ `--force`、丸ごと置き換えという生成の
単位、対象ファイルの列挙（`git ls-files --cached --others --exclude-standard -z`）、ツール名の
対応表11組、agents frontmatter のホワイトリスト9キーと `model` を除去する理由、settings のキー対応
4組と hook の変換規則、`SessionStart` matcher が**完全一致**であることへの対処、**変換しない
トップレベルキー3件とその帰結**、未知の入力をエラーにする3種、**削除ファイル検出と `--force`**、
終了コード表、性能上の前提。

**`env` の除外はこのターンで初めて記録された。** マージを通すためにスクリプトへ入れた判断で、
それまでどのドキュメントにも根拠が無かった。

### 2〜3. DDR 2本（`i0070-01` / `i0070-02`）

`i0070-01` には、リンク運用が成り立っていなかった理由として **`setup-gemini-links.sh` の
`TARGETS` が `agents` を含んでいなかった**（＝サブエージェント定義はGemini経路から一度も
見えていなかった）ことを明記した。却下案は5件（リンク運用の継続／配布物として配る／
`.gitignore` へ入れる／黙って落とす／差分更新）。

`i0070-02` には、**書き手（`set-header`）と検査側（`mark-done`）で「行が無いとき」の扱いを
変えた非対称**が意図的であることを、デッドロックを避けるためだと明記した。

### 4. `i0000-13` の無効化（frontmatterのみ）

```
$ git diff 805ab5f -- .claude/docs/ddr/ | grep -cE '^-[^-]'
4
```

削除行4件はすべて `note:` の置き換えで、**本文の行は1つも消えていない**。

### 5. `setup-gemini-links.sh` 参照の解消（件数付き）

```
$ git grep -n 'setup-gemini-links' -- ':!plans' ':!worklog' ':!reports' \
    ':!.claude/docs/ddr' ':!.gemini' ':!*index.jsonl' ':!HANDOFF.md' | wc -l
1
```

残る1件は `directory-structure.md` の「issue #70 以前はローカルリンク運用で、
`setup-gemini-links.sh` が…」という**経緯の説明**であり、実行を促す案内ではない。

### 6. `flow-id 5-4` の残存36件の内訳

**0件を期待する検索ではないので、全件を分類した**（`flow-id 5-4` は新設後も統括レポートを
指す有効な番号である）。

| 分類 | 件数 | 扱い |
|---|---|---|
| **新しい 5-4（統括レポート）を正しく指す** | 21 | そのまま（`SKILL.md` 6・`spec/issue-mr-workflow.md` 4・`Provider.sh` 系4・`Github.sh`/`Gitlab.sh` 2・テスト1・テンプレート1・README生成分2、ほか） |
| DDR本文（point-in-time） | 7 | **触らない** |
| `## 影響範囲` のchangelog | 2 | **触らない**（`create-commit.md` L197・`issue-mr-workflow.md` L2547。所属見出しを確認済み） |
| `plans/` `worklog/` `reports/` | 5 | タスク単位。flow-id 5-5 で消える |
| 今回の追記が引用として含むもの | 1 | `docs-workflow.md`（「壊れていた値」を引用している） |
| **繰り下げ漏れとして直したもの** | **1** | `reports/REVIEW-POINTS.md` L26 |

### 8. 重複していた単体テストの検出力

`test_search_frontmatter.sh` の2つのアサーションは**同一のコマンド・同一の期待値**だった
（どちらのフィクスチャも `title: 生成物`）。`build/gen/ビルド成果物` と
`.gemini/rules/変換生成物` へ分けたうえで、**意図的に除外を壊して独立性を確かめた**。

```
$ sed -i "s/build .gemini'/build'/" .claude/scripts/src/search-frontmatter.sh
$ bash .claude/scripts/test/test_search_frontmatter.sh | grep -E '^(FAIL|passed=)'
FAIL: main: .gemini/ 配下の index.jsonl は探索しない      ← 落ちた
（"build/ 配下の index.jsonl は探索しない" は落ちていない）
passed=106 failures=8
```

**`build` 側が落ちていないことが、2件が独立したことの証拠である。** 確認後にスクリプトを
復元し、`passed=114 failures=0` に戻ることを確かめた。

## 確かめられなかったこと

- **`.gemini/` を Gemini CLI が実際にロードできることは、このターンでも確認していない。**
  Gemini CLI がこの実行環境に無い。仕様書・DDRの「未決定事項」「受け入れた制約」へ明記した
  ので、**記録としては残ったが、事実としては未確認のまま**である。
- **policy engine の Workspace 層が無効であること**（upstream #18186）は、フェーズ2で
  gemini-cli のドキュメントを読んで確定した内容の再掲であり、このターンで測り直してはいない。
- **配布経路（`install-to-project.sh` が配布先で `.gemini/` を生成する）を実際に走らせていない。**
  `distribution-assets.md` へ書いた挙動は、スクリプトの読解に基づく。

## 設計への反映（反映しきれず次へ回したもの）

- **`.gitignore` L30 の `i36-01-…`**（存在しないDDR名。正しくは `i0036-01-…`）。issue #133 の
  ゼロ埋め改番に `.gitignore` のコメントが追随していない。issue #70 の成果と無関係なので
  **別issueへの切り出しを提案する**（AIからは起票しない）。
- **`.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` を生成対象から外すか**（フェーズ3の
  敵対的レビュー minor 指摘）。変換規則そのものを変える判断なので、フェーズ4の反映では扱わない。

## 残課題

- `【実装反映】敵対的レビュー指摘のコード修正.md`（フェーズ4の3本目）。`tr -d '\r'` の欠落、
  CRLFの `agents/*.md` 誤診、`--others` がローカル設定を焼き込む、`build_into` の0件メッセージ、
  前置フィルタの `read -d ''` の実機計測。
- 上記「次へ回したもの」2件。
