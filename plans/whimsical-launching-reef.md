---
title: issue #36 全体作業計画 — frontmatter index.jsonlをGit管理から外し生成物として扱う
type: guide
description: index.jsonlをGit管理から外しSessionStart hookで自動再生成する方針の全体作業計画
tags: [frontmatter, index-jsonl, session-start, gitignore]
keywords: [extract-frontmatter, index.jsonl, gitignore, SessionStart, create-commit, DDR, flow-id5-1]
---

# issue #36 全体作業計画

## 背景・目的

`.claude/scripts/src/extract-frontmatter.sh` が生成する `index.jsonl`（frontmatterの機械可読インデックス、リポジトリ内15箇所）は現在すべてGit管理下にあり、`.claude/rules/markdown-frontmatter.md` の定める「frontmatter更新時に手動で再生成しコミットに含める」運用に依存している。この運用には2つの構造的問題がある。

1. **マージconflict**: 複数ブランチが並行して別々のmarkdownのfrontmatterを編集すると、生成物である `index.jsonl` の近接行同士が競合する。
2. **流し忘れ事故**: 再生成をcommit前に手動で実行し忘れると、後から「`index.jsonl` だけを直す追加コミット」が発生する（`.claude/docs/spec/extract-frontmatter.md` の「未決定事項・懸念点」に既知の課題として明記済み）。加えて `flow-id 5-1` では `plans/index.jsonl` を個別削除して再生成する特殊対応まで運用に組み込まれている。

`index.jsonl` を **Git管理から外し生成物として扱う**ことで、この2つの問題は「index.jsonlがGitの差分・マージ対象から完全に外れる」という一点で構造的に解消される（Git管理から外れれば、コンフリクトも「コミットへの含め忘れ」も原理的に発生しなくなる）。残る論点は「ローカルの開発体験として、いつindex.jsonlを最新化するか」という利便性の設計のみ。

## 進め方の全体像

**フェーズ2（調査）は省略し、フェーズ3（作業）から着手する。**

事前調査（Exploreエージェント）で、`extract-frontmatter.sh` の出力単位・mtimeキャッシュの仕組み・性能特性、`create-commit.sh` の実装、既存15箇所の `index.jsonl` 一覧、`.gitignore` の記述慣習、DDR 0021 却下案4の前提、書き換え対象ドキュメントの一覧が判明済み。残っているのはコードベースの事実確認ではなく設計判断であり、フェーズ3で詰める。

### 採用する設計方針（ユーザー確認済み）

自動再生成のトリガーは、**`create-commit.sh`（全コミットが必ず経由する中核スクリプト）を改修するのではなく、`.claude/hooks/session-start.sh`（SessionStart hook）でセッション開始のたびに機械的に`extract-frontmatter.sh .`を1回実行する**方式を採用する。

理由・トレードオフ：
- Git管理から外れた時点で「マージconflict」「流し忘れによる追加コミット」という本issueの核心問題は解消済み。以降の自動再生成は「ローカルのindex.jsonlを検索・参照用途で妥当に新鮮に保つ」ための利便性機能であり、commit経路のような機構的強制は不要
- `create-commit.sh` は「`git add`/`git commit` のみを行う薄いラッパー」という既存方針を持ち、これを変更しないほうが影響範囲が狭い（全commitの実行時間に影響を与えない）
- `session-start.sh` は既に「非侵襲的（失敗してもセッション開始をブロックしない）」という設計方針を持っており、この方針をそのまま踏襲できる
- トレードオフ: 同一セッション内で複数回frontmatterを編集した場合、次のセッション開始まで `index.jsonl` は更新されない。ただしこれはGit管理外の派生ファイルの鮮度の問題に過ぎず、必要なら手動で `extract-frontmatter.sh .` を実行すればよい（受け入れ条件が求めるのは「手動実行がドキュメント上不要になっている」＝日常運用の既定動作の話であり、任意の手動実行そのものを禁止するものではない）

### フェーズ3（作業）の構成 — 【設計】【実装】を併記する

`create-commit.sh` を変更しない方針にしたことで影響範囲が小さくなったため、「設計が小規模で、実装方針と一体で判断できる」ケースに該当する。1ファイルで併記し、1回のレビューで合意を取る。

- **`plans/【設計】【実装】index.jsonl生成物化.md`**（flow-id 3-1〜3-10）
  - 設計: 下記「詰める論点」の結論を確定し、新規DDR `.claude/docs/ddr/0024-〜.md` のドラフトを含める
  - 実装: `.gitignore` 変更・既存15箇所の `git rm --cached`・`session-start.sh` 改修・関連ドキュメント更新
  - 動作確認: 新しいセッションを開始し `index.jsonl` が再生成されること、`git status` に `index.jsonl` が一切現れないこと、既存のセッション開始時コンテキスト注入（issue/PR情報）が壊れていないことを確認

### フェーズ4（反映） — 必ず実施

- **`plans/【設計反映】【AIアセット反映】index.jsonl生成物化のドキュメント反映.md`**
  - 設計反映: DDR `0024-〜.md` を確定・コミット。`.claude/docs/spec/extract-frontmatter.md` の「未決定事項・懸念点」該当項目を解消済みへ更新し、「影響範囲」にissue #36のエントリを追記（過去のchangelogエントリは書き換えない）
  - AIアセット反映: `.claude/rules/markdown-frontmatter.md`・`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/rules/docs-workflow.md`・（必要なら）`.claude/rules/directory-structure.md` を新方針に合わせて更新

## 詰める論点（フェーズ3【設計】で確定する）

1. **実装場所**: 既存 `session-start.sh` の `build_context` 相当に追記するか、独立した処理として同ファイル内に追加するか（別ファイルへの分離は、単一hookイベント内の処理としては過剰と考えられるため既定は同ファイル追記）
2. **失敗時の挙動**: 既存方針を踏襲し、`extract-frontmatter.sh` 失敗時もセッション開始をブロックしない（非侵襲的・fail-open）
3. **`.gitignore` パターンの書き方**: `**/index.jsonl` 一括パターン＋理由コメント（関連issue/DDR）を軸に検討。個別列挙は新規ディレクトリ追加時の追記忘れリスクを別の場所に移すだけになるため非推奨
4. **DDR 0021却下案4（自動削除）の再評価**: 「Git管理下にある」前提が変わったことで、誤削除時にGit履歴からの復旧手段が無くなる点に留意しつつ、却下維持（理由更新）を軸に確認
5. **既存15箇所の移行手順**: `.gitignore` 追加と `git rm --cached`（ワーキングツリーのファイル自体は残す）の順序・同一commitに含めるか
6. **`flow-id 5-1` の特殊対応の要否**: Git管理下でなくなるため「削除してコミットに含める」手順自体が不要になる。`rm -f plans/index.jsonl` というローカル衛生目的の一手を残すかは要確認（既定は完全削除、SKILL.mdの該当見出しごと除去）

## 想定する変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `.gitignore` | `index.jsonl`（生成物）を対象化するパターンを追加 |
| （既存15ファイルの `index.jsonl`） | `git rm --cached` でGit管理から除外 |
| `.claude/hooks/session-start.sh` | セッション開始時に `extract-frontmatter.sh .` を非侵襲的に実行するロジックを追加 |
| `.claude/rules/markdown-frontmatter.md` | 「Git管理下にあるためcommit直前に1回流す」という前提記述を、SessionStart自動化後の説明へ書き換え |
| `.claude/skills/issue-mr-flow/SKILL.md` | 「flow-id 5-1での `index.jsonl` の扱い」見出しの除去・全体フロー表5-1行の簡略化・「PRがflow-id 5-1実施前にマージされてしまった場合の対処」内の該当言及の除去 |
| `.claude/rules/docs-workflow.md` | `plans/` 行の「flow-id 5-1では…」括弧書きの除去 |
| `.claude/docs/spec/extract-frontmatter.md` | 「未決定事項・懸念点」の該当項目を解消済みへ更新、「影響範囲」にissue #36のエントリを追記 |
| `.claude/docs/ddr/0024-〜.md`（新規） | 本issueの設計判断・却下案を記録（次番号は0024） |
| `.claude/rules/directory-structure.md` | 矛盾記述がないか確認、必要なら軽微な追記 |

## 検証方法

- `bash -n .claude/hooks/session-start.sh` で構文チェック
- 新規セッションを開始し、SessionStart hookのコンテキスト注入が引き続き正しく動作すること（issue/PR情報）と、リポジトリルートで `index.jsonl` 群が再生成されることを確認
- `git status` で15箇所の `index.jsonl` が一切追跡対象外（untracked扱いにもならず無視される）になっていることを確認
- `tests/test_extract_frontmatter.sh` が既存どおりパスすること（`bash tests/test_extract_frontmatter.sh`）
