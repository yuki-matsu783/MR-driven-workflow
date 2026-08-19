---
title: 実装結果 ベースブランチ追従確認の検知スクリプトとフローへの組み込み
type: report
description: issue #67 のフェーズ3の実装結果。check-base-sync.sh・単体テストの新設と、SKILL.md・issue-mr-resume への組み込み、および実測による検証結果。
tags: [report, base-branch, issue-mr-flow, implementation]
keywords: [実装結果, check-base-sync, fetchOk, isShallow, hasCommonHistory, 単体テスト, AskUserQuestion, resume, 検証, 境界条件]
---

# 実装結果: ベースブランチ追従確認（issue #67 フェーズ3）

- 個別作業計画: `plans/【実装】【テスト】ベースブランチ追従確認の検知スクリプトとフローへの組み込み.md`
- 調査結果: `reports/20260819_base-branch-sync-check_調査結果.md`
- 実施日: 2026-08-19

## 変更したファイル

| # | ファイル | 種別 | 内容 |
|---|---|---|---|
| 1 | `.claude/scripts/src/check-base-sync.sh` | 新規 | 遅れの検知。作業ツリーを変更せずJSONを1つ出力 |
| 2 | `.claude/scripts/test/test_check_base_sync.sh` | 新規 | 純粋関数の単体テスト（29件） |
| 3 | `.claude/skills/issue-mr-flow/SKILL.md` | 変更 | 「作業開始・再開時のベースブランチ追従確認」節を新設し、`start`/`resume`/`sync` から参照 |
| 4 | `.claude/agents/issue-mr-resume.md` | 変更 | 手順7を新設し、現在地サマリへ「ベースブランチとの差分」を追加 |

**`Provider.sh` は変更していない。** 判定軸が違う機能を既存の低レベル関数へ混ぜず、
`check-base-conflicts.sh` と並ぶ独立したスクリプトとして切り出したため。

## 1. `check-base-sync.sh`

### 出力JSON（実リポジトリでの実行結果）

```json
{
  "base": "main", "baseRef": "origin/main",
  "baseSha": "1297215d7b6193d79aa001e24119d8c63638f376",
  "headRef": "HEAD", "headSha": "13295f9393bd1d22c7478fd2fa80bcbee671dcc9",
  "mergeBase": "1297215d7b6193d79aa001e24119d8c63638f376",
  "behind": 0, "ahead": 3,
  "changedFiles": [], "changedFilesTotal": 0, "changedFilesTruncated": false,
  "hasCommonHistory": true, "isShallow": true, "fetchOk": true, "isBehind": false
}
```

### 調査からの設計変更点（いずれも敵対的レビューの指摘による）

| 項目 | 調査時点の設計 | 実装 | 理由 |
|---|---|---|---|
| fetch の失敗 | `\|\| true` で握りつぶす（`check-base-conflicts.sh` と同じ） | **終了コードを `fetchOk` として出力** | 検知そのものが目的の本スクリプトでは、fetch失敗が「遅れていない」という誤報告になり、後段で拾われない |
| single-branch clone | エラーで止めて復旧コマンドを案内 | **既定のfetchを refspec 形 `+<base>:refs/remotes/origin/<base>` にして自動で扱う** | 通常のcloneでも同じ結果になることを実測。失敗経路が1つ減る |
| `--no-fetch` 時の `fetchOk` | （未定義） | **`false` ではなく `null`** | 「失敗した」と「そもそも試していない」を呼び出し側が区別できるようにするため |

### 判定が信頼できないことを示す3つのキー

`isBehind` だけを見ると、次の3つの状況で「追従済み」と誤読しうる。呼び出し側が識別できるよう、
すべてJSONへ出す。

| キー | 偽/真のときの意味 |
|---|---|
| `fetchOk: false` | fetchに失敗。古いリモート追跡参照を見ているため `behind` を過小評価しうる |
| `isShallow: true` | shallow clone。merge-base が取得済みの深さの外にあると `behind` が0と出うる |
| `hasCommonHistory: false` | merge-base が無い。`changedFiles` は空になり `behind` も参考値 |

## 2. 単体テスト

`bash .claude/scripts/test/test_check_base_sync.sh` → **`passed=29 failures=0`**

対象は外部コマンドを呼ばない2つの純粋関数（`BASH_SOURCE` ガードで `main` と分離）。

| 関数 | 検証したケース |
|---|---|
| `parse_left_right_to_reply` | 通常（`4<TAB>1`）／両方0／4桁／末尾CR／スペース区切り／空文字列／数値1つ／非数値／負数／3つ以上 |
| `truncate_file_list` | 0件／1件／上限ちょうど／上限+1件（切り詰めと全件数）／空行の除外／**日本語を含むパス**／上限0 |

**リポジトリ全体の単体テストも実行し、全て通ることを確認した**（11ファイル・合計399件、failures=0）。

## 3. 検証（使い捨ての別リポジトリで実測）

`main` を進め `feat` を1コミット進めたフィクスチャを作り、`check-base-sync.sh` を直接実行した。
**実リポジトリ・リモートには一切触れていない**（フィクスチャは確認後に削除済み）。

| ケース | 実行結果 | 判定 |
|---|---|---|
| behind>0 / ahead>0（典型的な遅れ） | `behind:5, ahead:1, isBehind:true, changedFiles:["m1.txt","m2.txt","m3.txt","shared.txt","ルール追記.md"]` | OK。**日本語ファイル名が8進エスケープされずに出た**（`core.quotepath=false` が効いている） |
| 追従済み | `behind:0, ahead:0, isBehind:false, changedFiles:[]` | OK |
| ahead のみ | `behind:0, ahead:1, isBehind:false` | OK。aheadを遅れと誤判定しない |
| **merge-base が無い**（`--orphan`） | `behind:6, ahead:1, isBehind:true, hasCommonHistory:false, mergeBase:null, changedFiles:[]` | OK。**`fatal` で落ちず**、3ドットdiffを実行していない |
| 変更ファイル60件（上限50超え） | `changedFilesTotal:60, changedFilesTruncated:true, changedFiles の長さ:50` | OK。件数を失わずに切り詰めている |
| 存在しないベースブランチ | 終了コード1＋復旧コマンド入りメッセージ | OK |

実リポジトリでの確認も行った。

```
$ bash .claude/scripts/src/check-base-sync.sh --no-fetch | jq -c '{fetchOk}'
{"fetchOk":null}
$ bash .claude/scripts/src/check-base-sync.sh --base nonexistent-branch; echo "終了コード=$?"
エラー: ベースブランチ origin/nonexistent-branch が見つかりません。次で作成できます:
  git fetch origin '+nonexistent-branch:refs/remotes/origin/nonexistent-branch'
終了コード=1
```

## 4. SKILL.md への組み込み

新節「作業開始・再開時のベースブランチ追従確認（issue #67）」を、**「PR作成後のdefaultブランチ
追従（監視）」節の直前**へ置いた。結果として、時系列（作業開始 → PR作成後 → マージ直前）の順に
3つの節が並ぶ。

- **挿入位置の前後を目視で確認した。** 直前の「レビュー完了合図の確認」節は箇条書きで終わって
  おり、節全体にかかる地の文が新しい節へ係ってしまう問題は起きていない
  （`.claude/rules/docs-workflow.md`）。空行も1つずつで揃っている。
- `start`（既存ブランチ検出時）・`sync`・`resume` の各手順から新節へリンクした。
- `resume` は手順を1つ増やし（旧5→新6）、**遅れがあった場合に `AskUserQuestion` で確認するのは
  呼び出し元の役割である**ことを明記した（サブエージェントは読み取り専用で判断しない）。

**flow-idは増やしていない。** issue #88 と同じく「特定のflow-idに属さない並行手順」として定めた。

## 5. `issue-mr-resume` への組み込み

- 手順7を新設（旧7・8は8・9へ繰り下げ）。`check-base-sync.sh` を実行して `behind` /
  `changedFiles` を取り、`fetchOk`・`isShallow`・`hasCommonHistory` が信頼性を損なう値なら
  その旨も添える。
- 現在地サマリのフォーマットへ `- ベースブランチとの差分:` を追加した。
- **「読み取り専用」の規定と `git fetch` の関係を明記した**。`git fetch` はリモート追跡参照を
  更新するだけで作業ツリー・ローカルブランチ・コミット履歴を変更しないため規定に反しない。
  逆に fetch しないと古い参照を見て誤報告することも併記した。

## 受け入れ条件との対応

| 受け入れ条件 | 対応 | 状態 |
|---|---|---|
| SKILL.md に追従確認のステップが追加され、実施タイミング（`resume` / `start` の既存ブランチ検出時）が明記 | 新節の「実施タイミング」表（`sync` も含めた4行） | 完了 |
| `issue-mr-resume` の報告項目にベースブランチとの差分（behindコミット数・変更ファイル） | 手順7＋現在地サマリの `- ベースブランチとの差分:` | 完了 |
| 遅れがある場合にユーザー確認を挟み、無断で取り込まないことが明記 | 新節の手順3（`AskUserQuestion`・選択肢3つ・「承認を得るまで取り込まない」） | 完了 |
| `Provider.sh` に関数追加・変更を伴う場合、単体テストが追加されている | **`Provider.sh` は変更していない**。新スクリプトに対し `.claude/scripts/test/test_check_base_sync.sh`（29件）を追加（`tests/` はこのリポジトリに存在せず、issue #63 で `.claude/scripts/test/` に集約されている） | 完了 |
| issue #46 との役割の違いが SKILL.md または spec から読み取れる | 新節の「既存2機構との役割の違い」表（#46・#88・#67 の3列比較） | 完了 |

## 残っている作業（フェーズ4へ）

- `.claude/docs/spec/check-base-sync.md`（新規）: 本スクリプトの正史仕様
- DDR: 「専用スクリプトとして切り出した理由」「fetchの失敗を握りつぶさない理由」と却下案
- `.claude/rules/git-workflow.md`: 追従確認の入口の1行と、rebaseを使わない方針の明記
  （調査で `.claude/rules/` 配下に `rebase` の語が0件であることを確認済み）
