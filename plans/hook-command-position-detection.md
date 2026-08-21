---
title: 全体作業計画: hookの検知をコマンド位置ベースにする（issue #53）
type: plan
description: block-direct-git-commit.sh / push検知hookの部分一致判定を、コマンド位置ベースの純粋関数へ置き換える全体作業計画
tags: [plan, hooks, issue-53]
keywords: [block-direct-git-commit, コマンド位置, 誤検知, ヒアドキュメント, クォート, push検知, 純粋関数, 単体テスト, CR, 敵対的レビュー]
---

# 全体作業計画: hookの検知をコマンド位置ベースにする（issue #53）

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- ブランチ: `claude/block-direct-git-commit-false-positives-mc1n43`

> **この計画はplanツール（Planモード）を使わずWrite/Editで作成した。** 本セッションはClaude Code
> on the web の非対話的実行環境で、Planモードの承認（flow-id 1-5）を待てないため。計画の位置づけ
> （issue＝ブランチにつき1つの全体作業計画）は通常どおりで、下位の個別計画（`plans/【*】〜.md`）と
> は分けて扱う。

## 背景

`.claude/hooks/block-direct-git-commit.sh` は `tool_input.command` に対する部分一致
（`grep -qiE 'git[[:space:]]+commit'`）だけで判定しており、**コマンド文字列のどこに該当語が
現れてもブロックする**。そのため、ヒアドキュメント本文・クォートされた文字列リテラル・日本語の
地の文に該当語が含まれるだけで誤検知する。issue #39 で2回、#45 で1回、#47 で1回、実際に踏んでいる。

同じ構造の問題を push検知hook（`post-push-usage-report.sh` / `post-push-compact-prompt.sh`）も
持つ。

## ゴール（issue #53 の受け入れ条件）

1. 判定ロジックを**外部コマンド呼び出しを伴わない純粋関数**として切り出し、単体テストを追加する。
2. **ブロックされる**こと: 単体のコミット実行／`cd src && ...` の複合コマンド／改行区切りの2行目。
3. **ブロックされない**こと: ヒアドキュメント本文／クォート内／日本語の地の文／該当文字列を検索する `grep` 等。
4. push検知hookにも同じ判定を適用する（しない場合は理由を記録する）。
5. 素通りリスクが改善効果を上回るなら、対応せずクローズしてよい（その判断を記録する）。

## フェーズ2〈調査〉

**実施する。** 実装方針が「どこまでシェル構文を解釈するか」の線引きに依存し、線引きを誤ると
受け入れ条件5（素通りリスク）に直結するため。次を調べる。

- 現行4hookの検知箇所と、`.claude/settings.json` の `if` フィルタとの二段構えの実態
  （コミット側には `if` が無く、push側にはある、という非対称。issue #53 コメント参照）。
- 誤検知・検知漏れの類型の洗い出し（何を除外すると何が素通りするか）。
- 判定アルゴリズムの候補比較（行分割＋前方一致 / セパレータ分割 / クォート追跡つき正規化）。
- **CRの影響の再判定**（issue #94 の「4hookには `tr -d '\r'` を足さない」という判断は、
  位置ベース判定では成り立たなくなる可能性がある。issue #53 コメントで明示的に申し送られている）。
- 性能（hookは毎ツール呼び出しで走るホットパス。fork回数で決まる）。

成果物は `reports/日付_hook-command-position-detection_調査結果.md` と同名の `.html`。

## フェーズ3〈作業〉

判定ロジックを `.claude/hooks/lib/` 配下の共通ライブラリへ切り出し、3つのhookから使う。

- ライブラリ（純粋関数・外部コマンド呼び出しなし）
- `block-direct-git-commit.sh` の判定差し替え
- push検知hook2本の判定差し替え（または適用しない理由の記録）
- `.claude/scripts/test/` への単体テスト（`passed=N failures=N` 規約）

## フェーズ4〈反映〉

**反映対象は flow-id 4-1 で洗い出す。** 現時点の見込み（確定ではない）:

- `.claude/docs/spec/command-position.md` — **新規**。判定アルゴリズムの仕様。
  3つのhookのコメントが既にこのパスを参照しているため、作成しない場合は参照側を直す
- `.claude/docs/spec/issue-mr-workflow.md` — hookの検知仕様（誤検知・検知漏れの制約が
  書かれている節）
- `.claude/docs/ddr/` — 判定の線引きと、あえて対策しない範囲を決めた記録
- `.claude/docs/ddr/i0000-09` — 「部分一致のため無関係なコマンドも誤ってブロックされる」と
  既知のトレードオフを記録している。**DDR本文は不変**のため、`note`（または `status`）の
  更新で対応する。更新後は `bash .claude/scripts/src/generate-ddr-list.sh` を再実行する
- AIアセット — `.claude/rules/git-workflow.md`・`.claude/rules/ai-command-style.md` の
  「該当2語を連続させない」回避策が、今回の変更後にどこまで必要かの見直し
- **ルート `REVIEW-POINTS.md`**（29行目付近）— 同じ回避策を観点として持っている。
  敵対的レビューが毎回読む位置にあるため、更新漏れが直接レビュー品質へ響く

**洗い出しの起点**は `grep -rn '部分一致' --include='*.md' .` とする（回避策の文言が
複数ファイルへ分散しているため、見込みの列挙だけに頼らない）。

## フェーズ5〈クローズ〉

コンフリクト検知 → 関連issue通知 → 片付け → Draft解除。マージは人間が行う。

## このセッション固有の制約

- **非対話的実行環境**のため、人間のレビュー往復（flow-id 2-3/2-8/3-3/3-8/4-3/4-8）を待てない。
  代わりに `adversarial-review` スキル（非対話セッションでのみ自律起動が許可されている）を
  各フェーズのpush後に実施する。該当するループ範囲の進捗記号は `[]` のまま残す。
- ブランチ名はハーネスの指定（`claude/...`）に従う。`.mrworkflow.json` の
  `branchPrefixTemplate`（`feature-<issue番号>-<slug>`）には合致しないが、ハーネスの指示が優先。
