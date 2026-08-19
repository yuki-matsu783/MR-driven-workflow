---
title: 調査結果 ベースブランチ追従確認の差し込み地点と検知方法
type: report
description: issue #67 の調査結果。既存機構がベースブランチの遅れを検知していないことの確認と、behind判定に使うgitコマンド・境界条件の実測結果。
tags: [report, base-branch, issue-mr-flow, investigation]
keywords: [ベースブランチ, 調査結果, behind, ahead, rev-list, left-right, 3ドット記法, merge-base, 境界条件, shallow, fetchOk, check-base-conflicts, sync_branch]
---

# 調査結果: ベースブランチ追従確認の差し込み地点と検知方法（issue #67）

- 個別調査計画: `plans/【調査】ベースブランチ追従確認の差し込み地点と検知方法.md`
- 実施日: 2026-08-19
- 実施環境: Claude Code on the web のリモート実行環境（Linux / git 2.x / `gh` CLI 無し）

## 結論（要点）

1. 「コンフリクトは無いが**ベースブランチに遅れている**」状態を検知する機構は、このリポジトリに
   **1つも無い**。issue #67 の前提は崩れていない。
2. 遅れの判定は `git rev-list --left-right --count origin/<base>...HEAD` **1回**で behind・ahead の
   両方が取れる。未取り込みの変更ファイルは**3ドット記法**（`HEAD...origin/<base>`）でなければ
   ならない（2点だと作業ブランチ自身の変更が混ざる。実測で確認）。
3. **merge-base が無いと3ドットdiffは `fatal` で終了コード128になる**（実測）。`set -euo pipefail`
   配下ではスクリプトごと落ちるため、merge-base の有無を先に判定して分岐する実装が必須。
4. （敵対的レビューの指摘を受けて追加）**`issue-mr-resume` サブエージェントが現在地サマリを
   組み立てる時点では、まだ `git fetch` されていない**。ここへそのまま behind を足すと、古い
   リモート追跡参照を見て「遅れていない」と報告する。**fetch の責務を新スクリプト側へ置く**
   ことで解決する。

## 調査1: 既存機構の守備範囲

「コンフリクトは無いが遅れている」を既存のどれかが検知できてしまわないかを確認した。**どれも
検知していない。**

| 機構 | 実際に見ているもの | 遅れ（behind）を見るか | 確認方法 |
|---|---|---|---|
| `sync_branch()`（`Provider.sh:693-702`） | `git fetch origin` → `git checkout <branch>` → `git pull --ff-only origin <branch>` | **見ない**。ベースブランチ名が関数内に一度も現れない | 該当行を直接確認 |
| `check-base-conflicts.sh`（flow-id 5-2 / issue #46） | テキストコンフリクト・DDR番号重複 | **見ない**。`grep -n 'behind\|ahead\|rev-list'` が0件 | grep（0件を確認） |
| `issue-mr-resume` サブエージェント | ブランチ・issue・PR・未解決コメント件数・plans/worklog・`現在のループ`・`追従監視` | **見ない**。現在地サマリのフォーマットに項目が無い | `.claude/agents/issue-mr-resume.md` の現在地サマリのテンプレートを確認 |
| `session-start.sh`（SessionStart hook） | ブランチ・VCS経路・issue・PR・owner/repo・未解決件数 | **見ない** | `build_context` 系の `lines+=(...)` を確認 |

**設計への反映**: 新しい判定軸（遅れ）を持つ検知手段が必要である、という前提が確認できた。
既存スクリプトの改造ではなく新規スクリプトを起こす方針（全体作業計画の案C）を維持する。

`sync_branch()` の実体（`.claude/scripts/src/vcs/Provider.sh:693`）:

```bash
sync_branch() {
  local branch="$1"
  git fetch origin
  if git branch --list "$branch" | grep -q .; then
    git checkout "$branch"
    git pull --ff-only origin "$branch"
  else
    git checkout -b "$branch" "origin/$branch"
  fi
}
```

`git fetch origin`（全refs）は行うため、**`origin/<base>` のリモート追跡参照自体は最新になる**。
足りないのは「その最新と作業ブランチを突き合わせて遅れを提示する」部分だけである。

### 誰が `git fetch` するか（地点ごとに違う）

| 地点 | `origin/<base>` を最新化するか | 根拠 |
|---|---|---|
| `start`（既存ブランチ検出） | **する**。`sync_branch()` の先頭が `git fetch origin` | 上のコード |
| `sync` | **する**（`sync_branch()` を呼ぶだけのサブコマンド） | SKILL.md `sync` 節 |
| **`resume`** | **しない**。`.claude/agents/issue-mr-resume.md` に `git fetch` は**0件**（`grep -c` で確認）。同エージェントは description で「読み取り専用」と規定されている | 実測 |

**`resume` にそのまま behind を足すと機能しない。** 古い `origin/<base>` を見て「遅れていない」と
報告してしまう（受け入れ条件2は形式的に満たされるのに検知としては無意味になる）。

**設計への反映**: fetch の責務は**新スクリプト（`check-base-sync.sh`）側**へ置く。`check-base-conflicts.sh`
が既に同じ設計（既定でfetchし `--no-fetch` で抑止）を採っており、これに揃えれば呼び出し元
（`resume` を含む）は「スクリプトを1回実行するだけ」で済む。`git fetch` はリモートから読むだけで
作業ツリー・ローカルブランチを変更しないため、`issue-mr-resume` の「読み取り専用」の規定
（Write/Editを持たず、ファイル修正とcommit/pushを行わない）とも矛盾しない。この解釈を
サブエージェント定義へ1行明記して、後任が迷わないようにする。

## 調査2: 差し込み地点

| 地点 | 差し込むか | 理由 |
|---|---|---|
| `start` 手順2「見つかった場合（セッション再開）」 | **する** | 既存ブランチを検出して `sync_branch` するだけの経路で、いつ作られたブランチか分からない |
| `start` 手順2「見つからない場合（新規作成）」 | **しない** | `new_issue_branch` が `<base_branch>` から切るため、定義上その時点で追従済み |
| `resume` | **する** | セッションを跨いだ引き継ぎ。issue #67 が挙げた実例（issue #60 のセッション）がこの経路 |
| `sync` | **する** | 「ブランチを最新化したいだけ」の経路。ここだけ確認が無いと、`sync` で済ませたセッションが素通りする |

**flow-id は増やさない。** issue #88（PR作成後のdefaultブランチ追従）が同じ判断をしており、
「特定のflow-idに属さない並行手順」として節を立てる形が既にある。追従確認は `start`/`resume`/
`sync` という**サブコマンドの手順の一部**であって、フローの新しい段ではない。

### 既存2機構との役割の違い（受け入れ条件の最終項目）

| | flow-id 5-2（issue #46） | PR作成後の追従監視（issue #88） | **本issue（#67）** |
|---|---|---|---|
| いつ | マージ依頼の直前（1回） | PR作成〜マージの間、随時 | **作業を開始・再開する時点** |
| 判定軸 | `hasConflict` | `hasConflict` | **behind（遅れ）** |
| 検知手段 | `check-base-conflicts.sh` | 同左 | `check-base-sync.sh`（新設） |
| 遅れているがコンフリクトしない状態 | **見逃す** | **見逃す** | **検知する** |

**この3つは代替関係ではなく補完関係**である。ベースブランチ側でルール・仕様だけが追記された
場合、テキストコンフリクトもDDR番号重複も起きないため既存2機構の `hasConflict` は偽のままだが、
作業ブランチはその追記を知らないまま実装・レビューを進めることになる。issue #67 が挙げた実例
（`.claude/rules/shell-script-style.md` へのルール追記10コミット分に気づかず作業していた）が
まさにこの形である。

## 調査3: gitコマンドと境界条件（実測）

使い捨てのフィクスチャ（`feature` が1コミット進み、`main` が4コミット進んだ状態。うち1コミットは
両ブランチが触っていない `shared.txt` の変更）を作って実測した。

### 3-1. behind / ahead の取り方

| コマンド | 実測結果 | 判断 |
|---|---|---|
| `git rev-list --count HEAD..origin/main` | `4` | behind は取れるが ahead は別途もう1回起動が必要 |
| `git rev-list --count origin/main..HEAD` | `1` | 同上 |
| **`git rev-list --left-right --count origin/main...HEAD`** | **`4<TAB>1`** | **採用**。1プロセスで behind・ahead の両方が取れる |

左が `origin/main` 側だけにあるコミット数（＝behind）、右が `HEAD` 側だけにあるコミット数
（＝ahead）である。`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」に照らし、
2回を1回へ減らせるこの形を採る。

### 3-2. 未取り込みの変更ファイル: 3ドットと2ドットの違い

| コマンド | 実測結果 | 判断 |
|---|---|---|
| **`git diff --name-only HEAD...origin/main`（3ドット）** | `m1.txt` `m2.txt` `m3.txt` `shared.txt` | **採用**。merge-base から見た**ベース側の変更だけ**が出る |
| `git diff --name-only HEAD..origin/main`（2ドット） | `f.txt` `m1.txt` `m2.txt` `m3.txt` `shared.txt` | **不採用**。作業ブランチ自身が追加した `f.txt` が混ざる |

2ドットは「2つの断面の差」なので、作業ブランチ側の変更が「ベース側では存在しない＝差分」として
現れる。これを「取り込めていないファイル」として提示すると、**自分が今書いたファイルを
『取り込め』と表示する**誤りになる。

### 3-3. 境界条件

| 条件 | 実測した挙動 | 実装での扱い |
|---|---|---|
| `origin/<base>` が存在しない | `git rev-list ...` が**終了コード128**（`fatal: ambiguous argument`） | 事前に `git rev-parse --verify --quiet "origin/<base>"` で確認し、明示的なメッセージで終了コード1にする（`check-base-conflicts.sh` と同じ形） |
| **merge-base が無い**（無関係な履歴） | `git merge-base` は終了コード1・出力空／`rev-list --left-right --count` は**成功**し `5<TAB>1`（両側の全コミット数）／**3ドットdiff は終了コード128**（`fatal: HEAD...origin/main: no merge base`） | **merge-base の有無を先に判定**し、無ければ `mergeBase: null`・`changedFiles: []`・`hasCommonHistory: false` として3ドットdiffを実行しない |
| behind = 0（追従済み） | `rev-list --left-right --count` は `0<TAB>0`、3ドットdiff は0件 | `isBehind: false`。誤検知なし |
| ahead > 0（通常の作業中）**［未実測・仕様からの推定］** | behind とは独立に数えられる | ahead を「遅れ」と誤判定しない（別キーで返すだけ） |
| fetch 前 **［未実測・仕様からの推定］** | 古い `origin/<base>` を見るため behind を過小評価する（数値としては確かめていない） | 既定でfetchを行い、`--no-fetch` で抑止できるようにする。**さらに、fetchの成否を `fetchOk` として出力へ含める**（下記「調査4」） |
| **shallow clone**（`git rev-parse --is-shallow-repository` が `true`） | **このリポジトリ自身が該当**（`.git/shallow` に6件の境界コミット、HEADから293コミット分を保持）。この状態でも `merge-base` / `rev-list --left-right --count`（`0<TAB>2`）／3ドットdiff はすべて**正常に動いた**。merge-base が保持している深さの内側にあるため | `isShallow` を出力へ含める。merge-base が取れなかった場合との組み合わせで「判定不能かもしれない」ことを呼び出し側が識別できるようにする |
| **single-branch clone**（`--depth 1 --branch <b>`） | `origin/<base>` の**リモート追跡参照が作られない**ため `git fetch origin <base>` を実行しても `origin/<base>` は現れず、後続がすべて終了コード128になる | **既定のfetchでこのrefspec形（`+<base>:refs/remotes/origin/<base>`）を使い、自動的に扱えるようにする。** 参照が作られ、shallow のままでも正しく判定できることを実測済み（`4<TAB>1` と正しい3ドットdiff）。通常のcloneでも同じ結果になることを確認しており、失敗経路を1つ減らせる。参照が無いまま到達した場合は、同じコマンドをエラーメッセージへ載せて終了コード1にする |

**merge-base が無いケースの挙動は、事前に予想していたものと違った。** `rev-list` は成功する一方
3ドットdiff だけが `fatal` になるため、「`rev-list` が通ったから安全」と考えて3ドットdiff を実行すると、
`set -euo pipefail` 配下でスクリプトごと落ちる。**この分岐は実装に必須である。**

## 調査4: 出力形式と既存スクリプトとの整合

`check-base-conflicts.sh` の規約に合わせられることを確認した。新スクリプトも同じ形にする。

| 項目 | `check-base-conflicts.sh` | 新スクリプトでの採用 |
|---|---|---|
| 引数 | `--base <branch>` / `--head <ref>` / `--no-fetch` / `-h`,`--help` | 同じ |
| fetch | `git fetch origin "$base" >/dev/null 2>&1 \|\| true` | **変える**。(1) refspec形 `+<base>:refs/remotes/origin/<base>` にして single-branch clone を自動で扱う。(2) **`\|\| true` で握りつぶさず、終了コードを `fetchOk` としてJSONへ出す**（下記） |
| ベースref不在 | stderrへメッセージ・終了コード1 | 同じ |
| 出力 | JSONを1つ stdout へ | 同じ |
| 終了コード | 検査が完了すれば0（判定結果は終了コードで表さない） | 同じ（`isBehind` はJSONで表す） |
| jq | 起動1回・可変長データは標準入力から | 同じ |
| 改行 | 末尾に `tr -d '\r'` | 同じ |
| テスト | 純粋関数を `BASH_SOURCE` ガードで分離し `.claude/scripts/test/` から source | 同じ |

**`fetch` だけ既存スクリプトと変える理由**: `check-base-conflicts.sh` がfetchの失敗を握りつぶせる
のは、コンフリクト検知はflow-id 5-2でもう一度必ず通るためで、取りこぼしても後段で拾われる。
一方**本スクリプトは検知そのものが目的**であり、fetchに失敗して古い `origin/<base>` を読むと
`isBehind: false` を返して呼び出し側からは「遅れていない」と区別がつかない。`isShallow` /
`hasCommonHistory` と同じく「判定の信頼性を識別できるようにする」枠で `fetchOk` を出す
（`--no-fetch` 指定時は `false` ではなく `null`。「失敗した」と「試していない」を区別するため）。

### 出力JSONの完全な形

`check-base-conflicts.sh` の先頭コメントと同じ体裁で、スクリプト冒頭に置く。

```json
{
  "base": "main", "baseRef": "origin/main", "baseSha": "...",
  "headRef": "HEAD", "headSha": "...", "mergeBase": "...",
  "behind": 4, "ahead": 1,
  "changedFiles": ["..."], "changedFilesTotal": 4, "changedFilesTruncated": false,
  "hasCommonHistory": true, "isShallow": false, "fetchOk": true, "isBehind": true
}
```

| キー | 意味 |
|---|---|
| `behind` | ベース側にあって作業ブランチに無いコミット数 |
| `ahead` | 作業ブランチ側にあってベースに無いコミット数（遅れの判定には使わない） |
| `changedFiles` | 未取り込みの変更ファイル（3ドット記法で取る）。先頭50件まで |
| `changedFilesTotal` / `changedFilesTruncated` | 切り詰め前の全件数 / 切り詰めたか |
| `hasCommonHistory` | merge-base が取れたか。偽なら `changedFiles` は空 |
| `isShallow` | `git rev-parse --is-shallow-repository` の結果 |
| `fetchOk` | fetchに成功したか（`--no-fetch` 時は `null`） |
| `isBehind` | `behind > 0`。**呼び出し側はこれを見る** |

**受け入れ条件の `tests/` について**: issue #67 の受け入れ条件は「`tests/` に単体テストが
追加されている」と書いているが、**このリポジトリに `tests/` ディレクトリは存在しない**。
issue #63 で「機構自身のテストは `.claude/scripts/test/` へ置く」と決まっており
（`.claude/rules/directory-structure.md`）、本issueもそれに従う。受け入れ条件を機械的に
照合して `tests/` を新設しないこと。

**変更ファイル一覧の件数上限**: ベースブランチが大きく進んでいると数百件になりうる。JSONの肥大化と
提示の読みづらさを避けるため、**先頭50件まで**をJSONへ含め、`changedFilesTotal`（全件数）と
`changedFilesTruncated`（真偽）を併記する。件数そのものは失わない形にする
（**本レポートでの設計判断**であり、規約に該当条文があるわけではない。趣旨は
`.claude/rules/shell-script-style.md` が issue #37 で記録した「失敗が握りつぶされて動いている
ように見える形にしない」と同じである）。**50件という数字は暫定値**で、実測や既存スクリプトの
前例に基づくものではない。実装時・運用後に調整してよい。

## 確かめられなかったこと

- **git bash（MSYS）実機での挙動**。本調査は Linux 上で行った。今回使うのは `rev-list` /
  `diff` / `merge-base` / `rev-parse` のみで、MSYS特有のパス変換・`jq` のCR付与の影響を受ける
  箇所は無い見込みだが、実機確認はしていない（`.claude/docs/spec/shell-scripts.md` の未決定事項と
  同じ状態）。
- **巨大なリポジトリでの所要時間**。`rev-list --count` は履歴の長さに比例するが、実測していない。
- **`--no-fetch` を付けた場合と付けない場合の実測差**。フィクスチャでは fetch 済みの状態しか
  作っておらず、「fetch を怠ると過小評価する」ことは git の仕様から述べているだけで、
  数値としては確かめていない。
- **merge-base が shallow の境界（grafted commit）の外にある場合の `rev-list --count` の値**。
  このリポジトリでは merge-base が保持範囲の内側にあり、再現できなかった。理屈のうえでは
  過小評価（＝「遅れていない」と誤報告）になりうるため、**`isShallow` を出力へ含め、
  呼び出し側が「shallowかつ結果が0件」のときに一度疑えるようにする**という形で、
  実測できていないことを設計側で吸収する。

## 設計への反映（フェーズ3への申し送り）

### A. 検知スクリプト `.claude/scripts/src/check-base-sync.sh`（新設）

1. `--base` / `--head` / `--no-fetch` を受ける。**fetch は既定でこのスクリプトが行う**
   （`issue-mr-resume` が現在地サマリを組み立てる時点ではまだfetchされていないため）。
   refspec形 `+<base>:refs/remotes/origin/<base>` を使い、**終了コードを `fetchOk` として出す**。
2. behind・ahead は `git rev-list --left-right --count origin/<base>...HEAD` 1回で取る。
3. 変更ファイルは3ドット記法（`HEAD...origin/<base>`）で取る。**その前に merge-base の有無を必ず判定する。**
4. それでも `origin/<base>` が無ければ終了コード1＋明示メッセージ（同じrefspecコマンドを案内）。
5. 変更ファイルは50件（暫定値）で切り詰め、全件数と切り詰めフラグを併記する。
6. 出力へ `isShallow` `hasCommonHistory` `fetchOk` を含め、**判定が信頼できない可能性を
   呼び出し側が識別できる**ようにする。
7. 純粋関数（件数の切り詰め・`rev-list --left-right` の出力パース）を `BASH_SOURCE` ガードで
   分離し、`.claude/scripts/test/test_check_base_sync.sh` から単体テストする。

### B. `.claude/skills/issue-mr-flow/SKILL.md`（受け入れ条件1・3・5）

新節「作業開始・再開時のベースブランチ追従確認」を、「PR作成後のdefaultブランチ追従（監視）」節の
**直前**へ置く（時系列: 作業開始 → PR作成後 → マージ直前 の順に3節が並ぶ）。書く内容:

- **実施タイミング**（受け入れ条件1）: `start` の既存ブランチ検出時・`resume`・`sync` の3地点。
  新規ブランチ作成時は不要（`<base_branch>` から切るため定義上追従済み）。
- **検知手順**: `bash .claude/scripts/src/check-base-sync.sh` を実行し `isBehind` を見る。
- **遅れがあったら `AskUserQuestion` で確認し、承認を得るまで取り込まない**（受け入れ条件3）。
  選択肢は「merge して取り込む（推奨）」「今は取り込まない」「rebase で取り込む（非推奨。
  `.claude/skills/resolve-conflict/SKILL.md` が rebase を使わないと定めている）」の3つ。
- **issue #46・#88 との役割の違い**（受け入れ条件5）: 上の調査2の比較表をそのまま置く。
- `isShallow` が真かつ `behind` が0のとき、`fetchOk` が偽のときは判定が信頼できない旨。
- **flow-idは増やさない**（issue #88 と同じ扱い）。

### C. `.claude/agents/issue-mr-resume.md`（受け入れ条件2）

- 調査手順を1つ追加し、`check-base-sync.sh` を実行して `behind` と `changedFiles` を取る。
- 現在地サマリのフォーマットへ `- ベースブランチとの差分:` の行を追加する。
- **「読み取り専用」の規定と `git fetch` の関係を1行明記する**（`git fetch` はリモートから
  読むだけで作業ツリー・ローカルブランチを変更しないため、この規定に反しない）。

## 敵対的レビューでの指摘と、その反映（フェーズ2・1回目）

`adversarial-review` スキルを push 直後に実施した（本セッションではユーザーの指示により各フェーズで
自動実施する）。指摘9件のうち4件をPRへインライン投稿し、5件は報告に留めた。**投稿した4件のうち
3件は、指摘を受けてから実機で裏取りが取れた**（shallowであること・`.claude/rules/` に `rebase` の
語が0件であること・`issue-mr-resume` に `git fetch` が0件であること）。

| 指摘 | 反映先 |
|---|---|
| 境界条件に shallow clone が無い | 個別調査計画の境界条件5を追加。本レポートの調査3-3・「確かめられなかったこと」へ実測結果を追記。設計へ `isShallow` を追加 |
| 差し込み地点ごとに「誰がfetchするか」の調査項目が無い | 個別調査計画の調査2へ追加。本レポート調査1へ節を新設。設計でfetchの責務を新スクリプト側に置くと決めた |
| 検証手順が境界条件1・3・4をカバーしていない | 個別調査計画の検証手順を境界条件ごとの表へ書き直し、使い捨てリポジトリの作り方と後始末を明記 |
| `.claude/rules/git-workflow.md` に rebase 方針は無い | 全体作業計画の参照先を `resolve-conflict` スキルへ訂正。`git-workflow.md` への追記をフェーズ4の候補に追加 |
| （報告のみ）調査前に結論を断定している | 全体作業計画の断定を「フェーズ2で検証する仮説」へ改め、崩れた場合の分岐を追記 |
| （報告のみ）受け入れ条件3に対応する成果物が無い | フェーズ3-3へ「`AskUserQuestion` で確認し承認まで取り込まないことを明記する」を追加 |
| （報告のみ）テストの範囲が未定・`tests/` との差異 | フェーズ3-2へ切り出す純粋関数の候補と、`.claude/scripts/test/` を採る理由を追記 |
| （報告のみ）命名規則外ブランチの影響 | 個別調査計画の調査2へ調査項目として追加 |
| （報告のみ）検証手順とコミットブロックhookの衝突 | 検証手順へ「スクリプトファイル経由で使い捨てリポジトリを作る」と明記 |

## 敵対的レビューでの指摘と、その反映（フェーズ2・2回目）

調査結果（本ファイルとHTML）を対象に2回目を実施した。指摘12件のうち7件をPRへインライン投稿し、
5件は報告に留めた。**このうち2件は実装そのものを変えた。**

| 指摘 | 反映 |
|---|---|
| **fetchを `\|\| true` で握りつぶすと、検知が目的の本スクリプトでは「遅れていない」と誤報告する** | `check-base-sync.sh` へ `fetchOk`（true / false / `--no-fetch` 時は null）を追加。調査4の表を「fetchだけ既存と変える」へ改訂 |
| **single-branch clone は refspec形fetchで自動回復できるのに、手動復旧を案内する設計になっていた** | 既定のfetchを `+<base>:refs/remotes/origin/<base>` へ変更（通常のcloneでも同じ結果になることを実測）。失敗経路が1つ減った |
| 「`resume` の経路には fetch が1つも無い」は調べた範囲より広い主張 | 「`issue-mr-resume` が**現在地サマリを組み立てる時点では**まだfetchされていない」へ精密化（SKILL.md `resume` 手順4は `start` 手順2相当へ進むため、報告の**後**にはfetchされうる） |
| 設計への反映がスクリプト実装のみで、受け入れ条件1・2・3・5の申し送りが無い | 「設計への反映」をA（スクリプト）・B（SKILL.md）・C（resumeエージェント）の3節に分け、受け入れ条件との対応を明示 |
| 出力JSONの完全なスキーマが無く、behind/aheadのキー名が一度も書かれていない | 調査4へ完全な出力JSONの例とキーの説明表を追加 |
| `.claude/rules/shell-script-style.md` に「silent truncation にしない」方針は存在しない | 本レポートでの設計判断であると明示し、50件が暫定値であることも明記 |
| 「実測した挙動」の表に未実測の行が混ざる／HTMLは「すべて実測」と断言 | 未実測の行へ `［未実測・仕様からの推定］` を付け、HTML側のラベルを外した |
| HTML版にmd版の差し込み地点表・調査3-1・調査4が欠落 | HTMLへ3節を追加し、節番号をmd版と一致させた |
| （報告のみ）「3点リーダ」は `A...B` 記法の呼称として誤り | 本レポート・スクリプトのコメントを **3ドット記法** へ統一（specへ転記されると恒久化するため） |
| （報告のみ）受け入れ条件の `tests/` と実際の `.claude/scripts/test/` の差異が正文に無い | 調査4へ明記（`tests/` を新設しないこと） |
| （報告のみ）「先に3行」なのに項目が4つ | 見出しを「結論（要点）」へ |
| （報告のみ）`tags` に日本語の値 | kebab-case（ASCII）へ。`調査結果` は `keywords` へ移動 |
