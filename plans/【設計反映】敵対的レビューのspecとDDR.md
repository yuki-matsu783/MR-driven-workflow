---
title: 【設計反映】敵対的レビューのspecとDDR
type: plan
description: issue #77 の個別反映計画（設計反映）。敵対的レビュー機構の正史仕様を新規specへ、意思決定をDDRへ記録する。
tags: [issue-mr-flow, spec, ddr, review]
keywords: [敵対的レビュー, 設計反映, spec, DDR, adversarial-review, REVIEW-POINTS, インラインコメント, position, AUTOMATION, 実施回数]
---

# 【設計反映】敵対的レビューのspecとDDR

- issue: [#77](https://github.com/yuki-matsu783/MR-driven-workflow/issues/77)
- 全体作業計画: `plans/prancy-herding-kahan.md`
- flow-id: 4-1〜4-10（1セット目）

## この計画の範囲

`plans/` `worklog/` `reports/` に散っているフェーズ2〈調査〉・フェーズ3〈設計・実装〉の成果を、
**永続する正史**（`.claude/docs/spec/` `.claude/docs/ddr/`）へ移す。

**`【AIアセット反映】`は別ファイル・別レビューで行う**（`issue-mr-flow/SKILL.md`「種別を複数併記する
場合／分ける場合」。正史ドキュメントへの記録と運用ルールの改訂では、レビューで求められる判断の
種類が違うため）。この計画のレビューが完了してから、そちらに着手する。

## 1. `.claude/docs/spec/adversarial-review.md`（新規）

既存specと同じ構成（背景・目的／仕様／影響範囲／設定項目／未決定事項・懸念点）で書く。
**新規作成には人間の承認が必須**（`.claude/rules/docs-workflow.md`）なので、この計画の承認をもって
それに代える。

| 節 | 書く内容 |
|---|---|
| 背景・目的 | レビューが人間の負荷に全面依存しており、AIの自己確認は追認に傾きやすい。組み込み `/code-review` はこのリポジトリ固有の落とし穴を見ない |
| 仕様: 全体像 | スキル → 専任サブエージェント（読み取り専用・findings JSONを返すだけ）→ 呼び出し元が投稿、という責務分離。承認の所在を1箇所へ寄せる意図 |
| 仕様: 起動ポリシー | 対話セッションではAIの自律起動を**禁止**。非対話（`AUTOMATION=1`）でのみ許す。未設定は常に対話扱い（既定を起動禁止へ倒す） |
| 仕様: 実施回数の上限 | 各フェーズ最大3回。状態は `.claude/state/adversarial-review/<ブランチ>.json`。**投稿の成否に関わらずレビュー実行直後に加算**する理由（失敗を口実に無限リトライできないようにする） |
| 仕様: findings JSONスキーマ | `path` / `line` / `old_line` / `side` / `severity` / `confidence` / `category` / `title` / `body`。重大度×確度による投稿／報告の振り分け表 |
| 仕様: GitHubの投稿 | `pulls/<n>/reviews` は**アトミック**（1行不正でレビュー全体が422）。有効行は `pulls/<n>/files` の `.patch` のhunkヘッダから範囲として求める。`line` 未指定は**有効行の最小値**へ寄せる（既存ファイルの部分変更では1行目がdiffに無いため）。提出済みレビューは削除できない |
| 仕様: GitLabの投稿 | `discussions` の `position` に必要な項目と `diff_refs` の取得元。**追加行は `new_line` のみ・削除行は `old_line` のみ・コンテキスト行は両方**という制約（違反すると `400 ... line_code must be a valid line code`）。`-H "Content-Type: application/json"` が必須 |
| 仕様: 署名 | インラインコメント本文の先頭に `Claude Codeより（敵対的レビュー）:` を付ける。理由は `reply` 手順2と同じ（CLIは人間のアカウントで認証されるため投稿者名で判別できない）。GitLabはまとめ役のレビュー本文が無いため特に重要 |
| 仕様: レビュー観点表 | ディレクトリごとの `REVIEW-POINTS.md`。対象ファイルのディレクトリからルートまで遡って集め、**浅い→深い**の順にマージする。複数対象ファイルがある場合は和集合 |
| 仕様: MCP経路 | `mcp__github__pull_request_review_write`（`create` → `add_comment_to_pending_review` → `submit_pending`）。GitLabはMCP対象外 |
| 影響範囲 | 追加・変更したファイルの一覧（`Provider.sh` / `Github.sh` / `Gitlab.sh` / 2スクリプト / 2スキル / 1サブエージェント / 4つの `REVIEW-POINTS.md` / 3つのテスト） |
| 設定項目 | `AUTOMATION`、`ADVERSARIAL_REVIEW_MAX_RUNS`（既定3）、投稿上限（既定10件） |
| 未決定事項・懸念点 | 非対話環境で `AUTOMATION=1` が実際に設定されるかは未検証（既定は起動禁止へ倒してある）／観点表が増えたときのマージ結果の肥大／`/code-review` との併用方針 |

**インラインコメントの位置指定に関する制約（GitHubの有効行・GitLabの `new_line`/`old_line` の
使い分け）は、specへ仕様として書くのに加え、DDRとして採用理由と却下案まで残す**
（flow-id 4-3のレビューで決定）。実機で試さないと分からない制約であり、「なぜ1行目に固定せず
有効行の最小値へ寄せたのか」「なぜ1件ずつ投稿しないのか」は、仕様の記述だけでは後から読み取れない
ため。下記 2-3 で扱う。

**`issue-mr-workflow.md` には、既存の該当節へ短い相互参照を1行足すに留める**（敵対的レビューの
仕様本体を二重管理しないため）。

## 2. DDR（新規・3件）

**番号は `0040` / `0041` / `0042` で確定**。flow-id 4-4で `main`（DDRは 0039 まで）を取り込み、
`ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d` が空であることを確認済み。
以降 `main` が進んだ場合はマージ直前に再確認する。

### 2-1. `0040-敵対的レビューは専任サブエージェントで独立コンテキストに切り出す.md`

- **決定**: 敵対的レビューを、読み取り専用の専任サブエージェント（`model: opus`）へ切り出す。
  渡すのはdiff・ファイルパス・マージ済み観点表だけで、「なぜそう実装したか」の経緯は渡さない。
- **却下案**: 組み込み `/code-review` の拡張で済ませる／メインエージェントの自己レビュー／
  指摘ごとに個別承認する／全体フローの必須ステップにする。
- **あわせて記録する判断**: 対話セッションでの自律起動を禁止した理由、実施回数を
  AIの自制ではなくスクリプトで強制した理由。

### 2-2. `0041-レビュー観点はディレクトリごとのREVIEW-POINTSへ外だしする.md`

- **決定**: レビュー観点をスキル本文へ直書きせず、`REVIEW-POINTS.md` として各ディレクトリに置き、
  祖先方向へ遡って集める。
- **却下案**: スキル本文へ直書き／単一の巨大な観点表／`.claude/rules/` の既存ファイルを
  そのまま観点として読ませる。
- **記録する理由**: 観点は対象ディレクトリごとに異なり、スキルに直書きすると
  「スキルの更新」と「観点の更新」が同じ変更単位になってしまうこと。

### 2-3. `0042-インラインコメントの位置指定はプロバイダごとの制約に合わせて縮退させる.md`

- **決定**: findings の位置指定を、投稿直前にプロバイダごとの制約へ合わせて縮退させる。
  - GitHub: 有効行を `pulls/<n>/files` の `.patch` のhunkヘッダから**範囲**として求め、
    `line` 未指定のfindingは**有効行の最小値**へ寄せる。範囲外の行・diffに現れないファイルは
    レビュー本文（サマリ）へ落とし、投稿自体は成立させる。
  - GitLab: **追加行は `new_line` のみ・削除行は `old_line` のみ・コンテキスト行は両方**を送る。
- **却下案**:
  - **`line` 未指定を1行目に固定する** — 既存ファイルの部分変更では1行目がdiffに含まれないことが
    多く、GitHubのレビューはアトミックなため1件の不正で全体が422になる。
  - **位置が確定しないfindingは投稿しない** — ファイル単位の指摘（設計の一貫性・命名・観点漏れ）は
    敵対的レビューで最も価値のある部類であり、落とすと機構の目的を損なう。
  - **GitLabで `new_line` と `old_line` を常に両方送る** — `400 ... line_code must be a valid
    line code` で失敗する。
  - **1件ずつ投稿し、失敗したものだけ捨てる** — GitHubは部分的な成功が無く、1件ごとに別レビューへ
    分けると通知が指摘数だけ飛ぶ。
- **あわせて記録する事実**: 提出済みのGitHubレビューは削除できない（個々のコメントは削除可）ため、
  事後の取り消しではなく**投稿前の絞り込み**（重大度×確度・投稿上限）が要になること。
  GitLabの `discussions` POSTは `--input` に加えて明示的な `-H "Content-Type: application/json"` を
  必要とすること。

## 3. worklog・reportsの削除

設計反映の一環として、このブランチの `worklog/*`（8件）と `reports/*`（HTML・md・
`reports/REVIEW-POINTS.md` を**除く**）を削除し、削除自体をコミットに含める
（`.claude/rules/docs-workflow.md` のライフサイクル表）。

- **`reports/REVIEW-POINTS.md` は削除しない**。これは観点表であって成果物レポートではなく、
  `reports/` ディレクトリに置く恒久的なファイルである。
- **`plans/REVIEW-POINTS.md` も同様に残す**。`plans/` 配下だが計画ファイルではない。
- **削除は `【AIアセット反映】`（2セット目）の完了後に行う**。先に消すと、2セット目の作業中に
  参照したい記録が失われるため。この計画では削除対象の確定までを扱う。

## 検証

```bash
bash .claude/scripts/src/extract-frontmatter.sh .   # 新規spec・DDRのfrontmatterが拾えること
ls .claude/docs/ddr/ | tail -3                       # 番号の連続と衝突の確認
```

- `.claude/docs/README.md` のDDR一覧へ2件を追記し、`.claude/docs/spec/` の目次にも新規specを載せる。

## スコープ外

- `.claude/rules/` `.claude/skills/` `AGENTS.md` への反映（`【AIアセット反映】`で扱う）。
- 敵対的レビュー機構自体の追加実装・仕様変更（フェーズ3で合意済みの範囲を記録するだけ）。
