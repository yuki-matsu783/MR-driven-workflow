---
title: issue #70 統括レポート
type: report
description: .gemini/を.claude/からの変換生成物へ改めたissue #70 の最終統括。変換器の新設・flow-id 5-3の新設・レビュー返信漏れを機構で塞ぐ変更・仕様書とDDRの整備を1枚にまとめる
tags: [report, summary, gemini, issue-70]
keywords: [sync-gemini-assets, flow-id-5-3, 未返信スレッド, 削除ファイル検出, 用語変換規則, i0070-01, i0070-02, 前置フィルタ, 超集合]
---

# 統括: `.gemini/` を `.claude/` からの変換生成物へ改める（issue #70）

issue #70 / PR #157 / ブランチ `claude/gemini-to-claude-migration-jc64gu`
コミット39件 / `.claude/` 側の変更61ファイル / `.gemini/` 側の生成物176ファイル

## 何を変えたか

### 1. `.gemini/` を「リンク」から「変換生成物」へ

`.claude/scripts/src/sync-gemini-assets.sh` を新設し、`setup-gemini-links.sh` を削除した。
`.gemini/` は `.claude/` を読んで**まるごと生成し直す**ものになり、**Git管理下へ入れてコミットする**。

| 対象 | 何をするか |
|---|---|
| `agents/*.md` | frontmatter を Gemini の `localAgentSchema` へ変換（ツール名の語彙11組・`tools` の配列化・`.strict()` が拒否する未知キーの除去・`model` の除去） |
| `settings.json` | `PreToolUse`→`BeforeTool`、`plansDirectory`→`general.plan.directory` 等のキー対応と hook の変換 |
| それ以外 | 内容を変えずにコピー |
| 除外 | 生成物とローカル状態（`index.jsonl` / `state/` / `settings.local.json`）のみ |

`--check` / `--dry-run` / `--force` の3モードを持ち、**`jq` が無ければエラーで止まる**。
**`.gemini/` に生成物へ含まれないファイルがあれば1バイトも書かずに中断する**（削除ファイル検出）。

### 2. フローへ `flow-id 5-3`（`.claude/` → `.gemini/` 変換同期）を新設

最終統括レポートの直前へ置き、旧 5-3〜5-6 を 5-4〜5-7 へ繰り下げた（全42 → **43ステップ**）。
21ファイル・機械置換125箇所＋手修正19箇所。**DDR本文84箇所は不変**（point-in-time の記録のため）。

### 3. レビュー返信漏れを機構で塞いだ

`HANDOFF.md` のヘッダへ `- 未返信スレッド:` を新設（項目6→7）し、**レビュー往復のループ範囲への
`mark-done` を、この値が `0` でなければ拒否する**ようにした。`adversarial-review` スキルへは
**手順8（投稿直後に未返信件数を記録する）**を足した。

### 4. 仕様書・DDR・AIアセットを整備した

- `.claude/docs/spec/sync-gemini-assets.md` を**新設**（スクリプト冒頭が `# 仕様:` として
  指していたパスの実体が無かった）。
- DDR 2本を追加し、`i0000-13`（リンク運用）を **frontmatter のみ** `superseded` にした。
- 削除済み `setup-gemini-links.sh` への参照3件、`flow-id 5-4` の繰り下げ漏れ1件を解消した。
- 用語を2つ改名した: `写像規則` → **`用語変換規則`**、`孤児検出` → **`削除ファイル検出`**。

### 5. 敵対的レビュー指摘のコード修正

CR の**入口**（`mapfile` が CRLF の `agents/*.md` を誤診）と**出口**（Windows native `jq` が
`settings.json` へ CR を付ける）の両方を塞いだ。`build_into` の失敗条件を「コピー対象0件」から
**「列挙0件」へ狭め**、0件時は原因を3つに切り分けて出すようにした。ローカル設定の除外は
`.gitignore` へ委ね、**配布先の `.gitignore` へも配る**ようにした。

## なぜそうしたか

### なぜリンクではなく変換なのか（DDR `i0070-01`）

リンク運用を続けるには `.claude/` 側を**両者が読める最大公約数**へ寄せるしかなく、主客が逆転する。
とくに `localAgentSchema` の `.strict()` に合わせるには `.claude/agents/*.md` から
`type` / `tags` / `keywords` を**消さなければならず**、`index.jsonl` の検索が壊れる。

**そもそもリンク運用は成り立っていなかった。** `setup-gemini-links.sh` の `TARGETS` は
`agents` を含んでおらず、**サブエージェント定義は Gemini 経路から一度も見えていなかった**。

### なぜ生成物なのに Git 管理下へ残すのか

`index.jsonl` は生成物として管理外にしている（DDR `i0036-01`）が、同じ扱いにすると
**配布先で再生成を忘れた時点で Gemini 側の資産がゼロになる**——リンク運用で実際に踏みうる失敗であり、
これを繰り返さないことが今回の主目的の1つである。加えて、管理外だと**変換が正しいかをレビューできない**。

**「生成物だから Git 管理外」は一般則ではない。人間やレビューが直接読むかどうかが分かれ目である**
（DDR一覧を生成物のまま管理下へ残した `i0135-01` と同じ理由）。

### なぜ「落とさずエラー」なのか

変換先の無いキー・ツール名を黙って落とすと、**Gemini 側が必要な設定を失ったまま静かに動く**。
しかも単体テストは「変換が通った」ことしか見ないので永久に緑のままになる。
実際に issue #103 の `env` 追加でこの停止が働き、理由付きで除外リストへ載せて解決した。

### なぜ文言強化ではなく機構なのか（DDR `i0070-02`）

issue #70 のフェーズ2で、投稿した10スレッドが返信ゼロのまま `mark-done` され、約1日
「未対応と区別が付かない」状態で残った。原因は手順の飛ばし・記録の欠落・記録の粒度の4つで、
**いずれも「気をつける」では再発する**。`mark-done` を止める側に置いた。

書き手（`set-header`）と検査側（`mark-done`）で「行が無いとき」の扱いを**意図的に非対称**にしている
——同じ扱いにすると、拒否からの復旧手段まで拒否されて詰むためである。

## 検証結果

| 項目 | 結果 |
|---|---|
| 単体テスト | 全17本 **passed=1104 failures=0** |
| perlテスト（OTel） | `test_otel_registry.pl` 12件・`test_session_id_finder.pl` 7件とも通過 |
| `sync-gemini-assets.sh --check` | 0（`.gemini/` は `.claude/` と同期） |
| DDR一覧 | 77件。`generate-ddr-list.sh --check` で差分なし |
| DDR本文の不変 | 分岐点からの削除行4件はすべて `note:` frontmatter |
| コンフリクト検知（flow-id 5-1） | `hasConflict: false` |
| frontmatter索引 | `files=154 built=0 failed=0` |

**検出力を実測した**（直した箇所を意図的に壊し、テストが落ちることを確かめた）。

| 壊した箇所 | 結果 |
|---|---|
| 削除ファイル検出を無効化 | 3件が落ちる |
| 未返信検査を無効化 | 5件が落ちる |
| `.gemini` の探索除外を無効化 | `.gemini` 側のアサーションだけが落ちる |
| `mapfile` の CR 除去を外す | 2件が落ちる |
| `convert_settings` の `tr -d '\r'` を外す | 1件が落ちる |
| 0件判定を旧仕様へ戻す | 3件が落ちる |
| 前置フィルタの2文字シーケンス除去を落とす | 1件が落ちる（`取りこぼし: git pu\` を報告） |

## この環境で検証できなかったこと

**Gemini CLI がこの実行環境に無い**（`command -v gemini` が空）。issue #70 の受け入れ条件のうち
「`Agent loading error` が再現しない」「hook が Gemini CLI 実行時に発火する」の**2件は未検証のまま
残る**。変換規則は一次情報（`google-gemini/gemini-cli` のソース）に基づいて確定し、入出力を
単体テストで固定するところまでを成果物とした。

**CR の挙動も Windows 実機では確かめていない**（スタブ `jq` による再現であり、後段に `head`/`sed`
が挟まる経路では実 jq と結果がずれる）。**`read -d ''` の read(2) コストも未計測**で、
計測手順だけを残した。

## spec・DDRへの反映先

| ファイル | 何を書いたか |
|---|---|
| `.claude/docs/spec/sync-gemini-assets.md`（新規） | 3モード＋`--force`／対象ファイルの列挙／用語変換規則3種／変換しないトップレベルキーとその帰結／**改行コードの扱い**／削除ファイル検出／終了コード／性能上の前提 |
| `.claude/docs/ddr/i0070-01-…` | `.gemini/` を変換生成物にし Git 管理下へ置く判断（却下案5件） |
| `.claude/docs/ddr/i0070-02-…` | レビュー返信漏れを文言ではなく機構で塞ぐ判断（却下案5件） |
| `.claude/docs/ddr/i0000-13-…` | **frontmatter のみ** `status: superseded` / `superseded_by: "i0070-01"` |
| `.claude/docs/spec/issue-mr-workflow.md` | flow-id 5-3 の新設と繰り下げ／hook登録節を生成物前提へ書き直し／issue #57 の未決定事項を「決定済み事項」へ移動 |
| `.claude/docs/spec/update-handoff-progress.md` | `--unreplied` とループ範囲への `mark-done` のゲート |
| `.claude/docs/spec/adversarial-review.md` | 手順8（投稿直後に未返信件数を記録する） |
| `.claude/docs/spec/distribution-assets.md` | `.gemini/` は配布物ではなく配布先で生成する |
| `.claude/rules/shell-script-style.md` | **hookの前置フィルタは語ごとに考えず、判定本体の正規化をそのまま施す**／`read -d ''` の計測手順 |
| `.claude/rules/docs-workflow.md` | 棚卸しの除外は**ディレクトリ単位ではなくファイル単位**で判断する |
| `.claude/rules/directory-structure.md` | `.gemini/` は全体が `.claude/` からの変換生成物である |

## 残課題

このPRでは対応せず、別issueへ切り出した。

| issue | 内容 | 状態 |
|---|---|---|
| [#159](https://github.com/yuki-matsu783/MR-driven-workflow/issues/159) | 前置フィルタを他の2本のhookへ広げる | **PR #162 でマージ済み**（本MRが main から取り込み、push系2本へも同型の実装を入れた） |
| [#171](https://github.com/yuki-matsu783/MR-driven-workflow/issues/171) | `.gitignore` が存在しないDDR名（`i36-01`）を指している | open |
| [#172](https://github.com/yuki-matsu783/MR-driven-workflow/issues/172) | `.gemini/hooks/` `scripts/` `docs/` を生成対象から外すかの判断 | open |
| [#105](https://github.com/yuki-matsu783/MR-driven-workflow/issues/105) | Gemini CLI のテレメトリ集計 | open。**`env` を変換できないため、このMRの方式では実現できないことを通知済み** |
| [#108](https://github.com/yuki-matsu783/MR-driven-workflow/issues/108) | `HANDOFF.template.md` の切り出し | open。**ヘッダが7項目になったことを通知済み** |

スコープ外として残したもの:

- **policy engine の変換**（`commandRegex` によるコミット/push拒否）。Workspace 層が**現在無効**で、
  リポジトリに置いても動かない（upstream issue #18186）。結果として、コミット強制の多重防御は
  Gemini 経路では hook の1枚だけになる。**スコープ外なのではなく、今は動かない。**
- **`env` の変換**（上記 #105）。
