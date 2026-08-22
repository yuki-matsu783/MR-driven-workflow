---
title: sync-gemini-assets.sh の実装結果
type: report
description: issue #70 フェーズ3の実装結果。.gemini/を.claude/からの変換生成物にするスクリプトと周辺改修13件・テスト54件の実施内容と検証結果
tags: [gemini, 実装, report, issue-70]
keywords: [sync-gemini-assets, 変換規則, ゴールデンファイル, 冪等性, 前置フィルタ, 超集合, 配布アセット, jq前提]
---

# 実装結果: `.gemini/` を `.claude/` からの変換生成物にする

個別作業計画: `plans/【実装】【テスト】sync-gemini-assetsと周辺スクリプトの改修.md`
前提となる設計合意: `plans/【設計】gemini変換規則とsettings写像の確定.md`
対象: issue #70 / PR #157 / flow-id 3-6

**この回はHTMLを作っていない。** flow-id 3-6 のHTMLは「結果を視覚的にまとめる必要があれば」で
必須ではなく（`.claude/rules/docs-workflow.md`）、本稿の内容は表で足りるためである。

## 結論

**計画の13件すべてを実施し、単体テスト54件を新設した。リポジトリ内の全テスト16本・1010件が緑。**
`.gemini/` は148ファイルの生成物になり、`--check` が0を返す（`.claude/` と同期している）。

**受け入れ条件のうち「変換後の `.gemini/` を Gemini CLI が実際にロードできること」は、この環境に
Gemini CLI が無いため依然として未確認である**（調査フェーズからの持ち越し。実装で解消していない）。

## 実施内容（13件）

| # | ファイル | 操作 | 実施内容 |
|---|---|---|---|
| 1 | `.claude/scripts/src/sync-gemini-assets.sh` | 新規 | 変換・コピー・除外・`--check`・`--dry-run`。458行 |
| 2 | `.claude/scripts/src/setup-gemini-links.sh` | 削除 | `git rm` 済み |
| 3 | `.claude/scripts/src/extract-frontmatter.sh` | 修正 | pathspec `:(exclude).gemini/**` ＋ `.gemini` 直接指定時の早期return |
| 4 | `.claude/scripts/src/search-frontmatter.sh` | 修正 | 理由コメントを「実体が2つあるため」へ。除外そのものは変更なし |
| 5 | `.gitignore` | 修正 | 9行削除（コメント4行＋パス5行） |
| 6 | `.gemini/settings.json` | 生成物化 | 手書き → 変換出力。148ファイルがGit管理下に入る |
| 7 | `.claude/scripts/test/test_sync_gemini_assets.sh` | 新規 | 54件 |
| 8 | `.claude/scripts/test/test_search_frontmatter.sh` | 修正 | コメント3箇所＋フィクスチャの語（`リンク`→`生成物`）。**期待値は変更なし** |
| 9 | `apply-.../scripts/sync-assets.sh` | 修正 | `.gemini/` 収集ブロック（20行）を削除 |
| 10 | `apply-.../scripts/install-to-project.sh` | 修正 | `.gemini/` のコピーをやめ、`jq` の前提チェックを冒頭へ足し、`.claude/` 配置後に生成を実行 |
| 11 | `apply-.../SKILL.md` | 修正 | 6箇所（併記4箇所＋確認項目＋スクリプト一覧） |
| 12 | `.claude/hooks/post-push-usage-report.sh` | 修正 | 前置フィルタ＋ヘッダの起動条件の説明 |
| 13 | `.claude/hooks/post-push-compact-prompt.sh` | 修正 | 同上 |

## 実装時に決めた3件（計画に無かった粒度）

計画では確定していなかった判断が3件あった。いずれも**変換規則そのものを変える**ため、ここに残す
（詳細な理由は同日の worklog）。

| # | 論点 | 決めたこと | 根拠 |
|---|---|---|---|
| 1 | hookのパスを `.gemini/hooks/` へ書き換えるか | **書き換えない**（`.claude/hooks/` のまま）。変換するのは `${CLAUDE_PROJECT_DIR}` → `$GEMINI_PROJECT_DIR` の1箇所だけ | `.gemini/` 側を指すと、**同期を忘れた状態で Gemini を動かしたときに Claude 経路と挙動が食い違う**。`.claude/` を指せば同期の鮮度に関わらず同じスクリプトが走る |
| 2 | `autoCompactWindow` の写像（調査で未判定だった1件） | **写像しない** | Gemini の `model.compressionThreshold` は**コンテキスト使用率の分数**（既定 0.5、`settingsSchema.ts` L1111–L1121）で、絶対値である Claude 側の値とは換算できない |
| 3 | 未知のトップレベルキーの扱い | **エラーで落とす** | 黙って落とすと「変換が情報を落としていること」を単体テストが永久に緑で通す（調査結果の警告そのもの） |

## 検証結果（計画の完了条件8項目）

| # | 条件 | 結果 |
|---|---|---|
| 1 | `bash -n` が全変更ファイルで通る | **OK**（9ファイル） |
| 2 | `test_sync_gemini_assets.sh` が `failures=0` | **OK**（`passed=54 failures=0`） |
| 3 | `test_search_frontmatter.sh` が `failures=0` | **OK**（変更前後とも `passed=114 failures=0`。期待値を変えていないことの裏付け） |
| 4 | 生成 → `--check` が0 | **OK** |
| 5 | `.gemini/**/index.jsonl` が1件も生成されない | **OK**（`extract-frontmatter.sh .` の後で0件） |
| 6 | `git status` に意図しない生成物が無い | **OK**（`.stackdump` / `.bak` / `.orig` いずれも0件） |
| 7 | 配布アセットに `.gemini` への言及が残っていない | **一部未達。下記** |
| 8 | 配布アセット2スクリプトで `bash -n` が通る | **OK** |

### 7 が満たせない理由（計画の判定基準のほうを直すべき箇所）

計画は `sync-assets.sh` / `install-to-project.sh` の `.gemini` 言及を**0件**と定めていたが、
**「配布先で生成する」と決めた時点でこの基準は成立しなくなっていた。** 生成するには、
配布スクリプトが生成コマンドを呼ぶ必要があるためである。

実際に残っているのは次の2種類だけで、いずれも**配布資産としての言及ではない**。

| 残っている言及 | 種類 |
|---|---|
| `install-to-project.sh` の生成呼び出し（`sync-gemini-assets.sh` の実行）とその理由コメント | 生成の実装 |
| `sync-assets.sh` の「配布物へ含めない」旨のコメント | 削除した理由の記録 |

**削除ブロックそのものは0件である**（`safe_copy_dir .gemini` / `mkdir -p .gemini` /
`rm .gemini/rules/go-applications.md` / `/.gemini/usage-state/` 等の ignore 行はすべて消えた）。

## 実装中に見つけて直した不具合3件

いずれも**新設したテストが検出した**もので、テストが空振りしていないことの裏付けでもある。

| # | 不具合 | 直し方 |
|---|---|---|
| 1 | 未知のツール名のエラーメッセージから**ツール名が消える**（`map_tool_name_to_reply` が失敗時に `REPLY` を空にするため） | 引く前に名前を退避する |
| 2 | ゴールデン比較が末尾改行の扱いで常に落ちる | 両辺をコマンド置換で受け、末尾改行は別に表明する |
| 3 | **フィクスチャがドキュメント索引に載る**（`.md` は無条件に走査されるため、`doc-search` の結果へ混ざる） | フィクスチャの拡張子を `.md.fixture` / `.md.expected` にする |

3 は `.gemini` 除外と同じ性質の副作用で、**エラーが出ないため気づくのは検索結果が汚れてから**で
ある（実際に一度そうなった）。

## テストの検出力を確かめた2件

「異常が無ければ何も出ない」形のテストは、パターンが実データに合っていないと常に成功する
（`.claude/rules/shell-script-style.md`「テスト」）。T11・T12 はまさにその形なので、
**意図的に壊して検出できることまで確かめた**。

| テスト | 壊し方 | 結果 |
|---|---|---|
| T11（前置フィルタは精密判定の超集合） | パターンを `*push*` → `*git push*` へ狭める | **2件の取りこぼしを検出**（`git -C /x push` / `git --no-pager push origin HEAD`） |
| T12（足切り時に `jq` を1回も呼ばない） | ペイロードを push のものへ差し替える | **スタブ `jq` が1回呼ばれる**ことを確認（仕組みが働いている） |

## 性能（前置フィルタの効果）

`if` を落とした2本は、非pushのペイロードで **`jq` を1回も起動しない**（T12 で機械的に検証済み）。
設計時の実測（execve 6 / clone 14 → 1 / 0）と整合する。

**`block-direct-git-commit.sh` / `post-issue-create-notice.sh` は対象外**である（この2本は
`if` を持たず、Claude Code でも毎回起動している。同じ手当てをすると効果は大きいが目的が別の
ため、**issue #159** として切り出した）。

## 残る未確認（受け入れ条件の未達）

| 項目 | 状態 |
|---|---|
| 変換後の `.gemini/agents/*.md` を Gemini CLI がロードできること | **未確認**（CLI が無い） |
| 変換後の `.gemini/settings.json` の hook が実行時に発火すること | **未確認**（同上） |
| `general.plan.directory` に policy が要るか | **未確認**。ただし要ったとしても Workspace 層が無効のためリポジトリからは配れない（調査結果） |

## 次にやること

**flow-id 5-3（`.claude/`→`.gemini/` 変換同期）の新設と以降の繰り下げ**
（`plans/【AIアセット作成】flow-id5-3の新設と以降の繰り下げ.md`）。
**本作業の 3（`extract-frontmatter.sh` の `.gemini` 除外）がその前提条件**であり、これは完了した。
