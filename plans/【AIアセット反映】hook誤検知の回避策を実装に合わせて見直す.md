---
title: 個別反映計画: hook誤検知の回避策を実装に合わせて見直す
type: plan
description: issue #53の変更を受けて、.claude/rules/とREVIEW-POINTS.mdの「該当2語を連続させない」回避策を見直す個別反映計画
tags: [plan, AIアセット反映, rules, issue-53]
keywords: [git-workflow, ai-command-style, REVIEW-POINTS, 回避策, 誤検知, ファイル経由, MCP, 返信truncate]
---

# 個別反映計画: hook誤検知の回避策を実装に合わせて見直す

- issue: [#53](https://github.com/yuki-matsu783/MR-driven-workflow/issues/53)
- 全体作業計画: `plans/hook-command-position-detection.md`
- 実施結果の記録先: `reports/2026-08-21_hook-command-position-detection_AIアセット反映結果.md`

> 本ファイルは**これから何をするか**のみを書く。実施した結果は上記 `reports/` へ記録する。
> 設計反映（`plans/【設計反映】…md`）とは**別の合意単位**として分けている
> （`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 目的

AIアセット（rules・skills・REVIEW-POINTS）に散らばる「`git` と `commit`/`push` を半角スペース
区切りで連続させない」という回避策が、今回の変更後にどこまで必要かを見直す。

**この回避策を無条件に消さない。** 消してよいかは、hookごと・状況ごとに答えが違う。

| 対象 | 変更後の状況 | 回避策の要否 |
|---|---|---|
| コミットブロックhook | コマンド位置判定になり、地の文・クォート内・ヒアドキュメント本文では発火しない | **不要になった**（ただし下記の縮退時を除く） |
| push検知hook（スクリプト側） | 同上 | 同上 |
| push検知hook（`.claude/settings.json` の `if`） | **変えていない。** 照合規則は issue #47 から未解明 | **必要なまま** |
| 1行が8192バイトを超える／`eval "$var"` 等 | 部分一致へ縮退する | **必要**（誤検知が残る） |
| ライブラリを読めない環境（bash 4.3未満・配布漏れ） | 部分一致へ縮退する | **必要** |

したがって結論は「回避策の削除」ではなく、**「いつ必要か」を書き分ける**ことになる。

## 反映対象と、それぞれ何をするか

| ファイル | 箇所 | 何をするか |
|---|---|---|
| `.claude/rules/git-workflow.md` | 「コミット運用」の既知トレードオフ／「push検知hookの誤検知（AIエージェント向け注記）」節 | 「部分一致のため地の文でも誤ってブロックされる」を現状へ更新する。**issue #23 で計3回踏んだという記録は残す**（point-in-time の観測）。回避策は上表の「必要なまま」の場合へ限定して書き直す |
| `.claude/rules/ai-command-style.md` | 「コメント本文でのhook誤検知に注意する」節 | 同上。**「コミットをブロックするhookは地の文でも必ず発火する」という断定は事実でなくなる**ため、ここは書き換えが必須。両論併記のまま残している `if` 側の扱いは変えない |
| ルート `REVIEW-POINTS.md` | 25〜29行目「hookの誤検知を招く書き方」 | 観点として残すが、条件を上表に合わせる。**敵対的レビュアーが毎回読む位置**にあるため、古いままだと毎回この観点で誤った指摘が出る |
| `.claude/rules/shell-script-style.md` | 498行目付近（hookのコマンド文字列にCR除去は不要という例外） | 判定が `grep` の部分一致から**トークン走査**へ変わったため、**理由が変わった**。結論（`tr -d '\r'` は不要）は同じだが、根拠を現状（`IFS` にCRを含む・ヒアドキュメント区切り語の比較前に末尾CRを落とす）へ書き換える |
| `.claude/skills/adversarial-review/SKILL.md` | 149行目（findingsはファイル経由で渡す） | 理由の1つだった「hook誤検知語の混入」は弱まるが、**jqの引数長上限という理由は残る**ため結論は変えない。理由の記述だけを正確にする |

## あわせて記録する運用上の発見（issue #53 の作業中に踏んだもの）

`.claude/skills/issue-mr-flow/SKILL.md`「`gh`/`glab` CLI不在時のMCPフォールバック」節へ追記する。

- **`mcp__github__add_reply_to_pull_request_comment` は、本文に `<` で始まる語が含まれると
  そこで本文を切り捨てて投稿する**（実測。返信が途中で終わった状態で投稿され、エラーにならない）。
  投稿後に `get_review_comments` で本文の末尾を確認し、切れていたら記号を避けて書き直す。
- 同じ節に、`comments` / `reply` ループでのMCPツール対応表があるため、その表の近くへ置く。

## やらないこと

- **回避策の一律削除。** 上表のとおり、必要な状況が残る。
- **`.claude/settings.json` の `if` フィルタの変更。** 発火が増える方向で本issueと逆向き。
- **`.claude/rules/powershell-encoding.md`。** 今回の変更と無関係。
- **`.claude/VERSION` の更新。** 提案はするが、決定は人間が行う。

## 検証

- 更新した各ファイルのfrontmatterが `.claude/rules/markdown-frontmatter.md` に沿うこと。
- `bash .claude/scripts/src/extract-frontmatter.sh .` が成功すること。
- ルート `REVIEW-POINTS.md` の観点を、`bash .claude/scripts/src/collect-review-points.sh` が
  従来どおり収集できること。
- 「必要なまま」と書いた状況（縮退時・`if` 側）が、実装結果レポートの「残る素通り」表と
  食い違っていないこと。
