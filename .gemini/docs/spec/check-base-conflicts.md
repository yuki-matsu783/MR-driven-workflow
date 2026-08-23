---
title: defaultブランチとのコンフリクト検知（check-base-conflicts.sh）
type: spec
description: マージ依頼前にdefaultブランチとのコンフリクト有無を作業ツリーを変更せずに判定するスクリプトの仕様。テキストコンフリクトに加え、gitが検知できないDDR識別子の重複も調べる
tags: [conflict, script, workflow, spec]
keywords: [check-base-conflicts, merge-tree, DDR識別子, DDR番号, issue番号ベース, semantic conflict, defaultブランチ, hasConflict, resolve-conflict, flow-id-5-1, 追従監視, check-base-sync, 判定軸]
---

# defaultブランチとのコンフリクト検知（check-base-conflicts.sh）

## 背景・目的

issue #46「マージ依頼前にdefaultブランチとのコンフリクトを検知・解消するフローを整備する」。

`.claude/skills/issue-mr-flow/SKILL.md` のマージ依頼フローには、defaultブランチとの
コンフリクト有無を確認するステップが無かった。コンフリクトの存在に気づくのは人間がマージ操作を
試みた後になりがちで、解消手順も定義されていなかったため、都度その場の判断で解消されていた。

**とくに問題だったのは、gitが「コンフリクト無し」と報告する種類の衝突があること**である。
両ブランチがそれぞれ新しいDDRを追加すると、`0027-A.md` と `0027-B.md` のようにファイル名が
異なるため、gitは何も報告せず両方をマージする。結果として同じ識別子のDDRが2つ並ぶ。
`git merge` / `git merge-tree` に頼るだけでは、この衝突は永久に検知できない。

過去の発生実績（本スクリプトで再現確認済み）:

| PR | issue | 重複した番号 | テキストコンフリクト |
|---|---|---|---|
| #29 | #13 | あり | — |
| #37 | #36 | `0024` | `index.jsonl` 7件（deleted by us）・`docs-workflow.md`・`README.md`・`HANDOFF.md` |
| #49 | #48 | `0026` | — |
| #52 | #45 | `0027` | `.claude/docs/README.md`・`tests/test_vcs_provider.sh` |

## 仕様

### 呼び出し

```bash
bash .claude/scripts/src/check-base-conflicts.sh [--base <branch>] [--head <ref>] [--no-fetch]
```

| オプション | 既定 | 意味 |
|---|---|---|
| `--base <branch>` | `.mrworkflow.json` の `defaultBaseBranch`（既定 `main`） | 比較対象のdefaultブランチ名。実際には `origin/<branch>` を参照する |
| `--head <ref>` | `HEAD` | 比較元。任意のコミットを指定できる（過去事例の再現・テストに使う） |
| `--no-fetch` | （fetchする） | `git fetch origin <base>` を省略する。ネットワークが無い環境や、直前にfetch済みの場合に使う |

`.mrworkflow.json` が無い場合は `defaultBaseBranch=main` / `ddrDirs=[".claude/docs/ddr"]` を既定とする。

### 出力

判定結果のJSONをstdoutへ1つ出力する（`Provider.sh` の各関数と同じ規約）。

```json
{
  "base": "main",
  "baseRef": "origin/main",
  "baseSha": "3e3ee03...",
  "headRef": "HEAD",
  "headSha": "abc1234...",
  "ddrDirs": [".claude/docs/ddr"],
  "textualConflictFiles": [".claude/docs/README.md"],
  "duplicateDdrNumbers": [
    { "number": "0027", "files": [".claude/docs/ddr/0027-A.md", ".claude/docs/ddr/0027-B.md"] },
    { "number": "i0133-01", "files": [".claude/docs/ddr/i0133-01-A.md", ".claude/docs/ddr/i0133-01-B.md"] }
  ],
  "hasTextualConflict": true,
  "hasDuplicateDdrNumber": true,
  "hasConflict": true
}
```

### 終了コード

**検査が完了すれば常に0**。コンフリクトの有無は終了コードではなく `hasConflict` で表す。
`origin/<base>` が見つからない・`git merge-tree` が異常終了した等、検査自体が失敗した場合のみ非0。

呼び出し側（スキルの手順・hook）は `set -euo pipefail` 配下で動くため、「コンフリクトがある」
という**正常な検査結果**で呼び出し元のスクリプトが停止してしまう設計を避けた
（`.claude/rules/shell-script-style.md`「テスト」節の、終了コードを状態の表現に使わない方針と同じ）。

### 検知1: テキストコンフリクト

```bash
git -c core.quotepath=false merge-tree --write-tree --name-only --no-messages <head> <base>
```

- **作業ツリー・インデックスを一切変更しない**（`git merge` を試して `git merge --abort` する方式と
  異なり、中断された場合でもリポジトリが壊れた状態に残らない）。
- 終了コード0＝コンフリクト無し、1＝コンフリクト有り、2以上＝エラー。
- 標準出力の1行目は書き出されたツリーのOIDなので落とし、2行目以降をコンフリクトファイル一覧とする。
- `-c core.quotepath=false` は、日本語ファイル名（DDR等）が8進エスケープされるのを防ぐため
  （`Provider.sh` の `get_branch_work_files` と同じ理由）。
- git 2.38以降が必要（`merge-tree --write-tree`）。実機確認は git 2.43.0。

### 検知2: DDR識別子の重複（semantic conflict）

`ddrDirs` 配下のmarkdownを `<head>` 側と `<base>` 側の両ツリーから列挙し（`git ls-tree -r`）、
和集合を取ってファイル名から取り出した**識別子**でグルーピングする。**同じ識別子に相異なるパスが
2つ以上属していれば重複**とする。

識別子は次の2形式を受け付ける（issue #133）。命名規則は
`.claude/rules/markdown-frontmatter.md`「DDRの識別子」が正。

| 方式 | ファイル名 | 抽出される識別子 | 判定順 |
|---|---|---|---|
| issue番号ベース（新規はこちら） | `i<issue番号4桁ゼロ埋め>-<枝番2桁>-タイトル.md` | `i0133-01` | 先 |
| 連番（旧方式・本リポジトリには残っていない） | `NNNN-タイトル.md` | `0027` | 後 |

- 正規表現は `^(i[0-9]{4,}-[0-9]{2})-` と `^([0-9]{4})-`。どちらにも一致しないファイル
  （`index.jsonl`、3桁以下の連番、枝番が1桁・3桁のもの、大文字 `I` 始まり、**ゼロ埋めしていない
  issue番号**）は対象外。
  **issue番号を4桁以上・枝番をちょうど2桁に限定しているのは、`i133-01`（ゼロ埋め漏れ）や
  `i0133-1-…`（枝番1桁）のような表記の揺れが別の識別子として通り、同じDDRが2つの識別子を
  持ってしまうのを防ぐため。** 4桁ゼロ埋めはファイル名の辞書順を数値順と一致させる目的でもあり、
  `generate-ddr-list.sh` のglob順の出力がそのままDDR一覧になる（issue #135）。
  上限を設けず `{4,}` にしているのは、issue番号が9999を超えても破綻させないため。
- 新方式を先に判定するが、先頭が数字かどうかで両者は排他なので順序に依存はしない
  （`0133-…` と `i0133-01-…` は別の識別子として扱われ、同一視されない）。
- 作業ツリーではなく**両ブランチのツリー**を見るため、まだマージしていない段階で判定できる。
- 実装は外部コマンドを呼ばない純粋関数（`ddr_identifier_to_reply` /
  `find_duplicate_ddr_identifiers`）へ分離し、`.claude/scripts/test/test_check_base_conflicts.sh`
  で単体テストしている（`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」に従い、
  ループ内で `jq` 等を起動しない）。

#### issue #133以降、この検知が拾うもの

**新方式では、別ブランチ同士で同じ識別子が生まれることは原理的に無い**（issue番号はGitHub/GitLabが
中央で採番する）。過去4回の形の衝突は起きない。それでもこの検知を残しているのは、次の2つが
残るためである。

1. **旧形式（4桁連番）のDDR同士。** 本リポジトリのDDRは issue #133 で全件改番したため
   1件も残っていないが、**改番前に切られたブランチ**や、**この機構を旧版のまま導入した別
   リポジトリ**には残る。このため旧形式の抽出は残してある。
2. **同一issueへの追加作業を2つのブランチで並行して行った場合。** 枝番だけはローカルで決めるため、
   両ブランチが同じ枝番を採りうる。

解消手順は前者が `resolve-conflict` スキルの類型A-1（従来どおり繰り下げ改番）、後者が類型A-2
（枝番だけを繰り下げ、あわせて並行作業の是非を人間へ確認する）。

#### JSONのキー名を改名していないこと

`duplicateDdrNumbers` / `hasDuplicateDdrNumber` は「番号」という語を含むが、値は連番と
issue番号ベースの識別子の両方を取る。**キー名を改名しないのは意図的**であり、複数のスキル・specから
参照される公開インターフェースの改名が、まさにissue #133が無くそうとしている「参照の追従漏れ」を
新たに作り出すためである。一方、内部の純粋関数名は実態に合わせて改名した（参照が本体と
単体テストの2ファイルに閉じているため）。**どちらかへ揃えようとする前に、
`.claude/docs/ddr/i0133-01-DDR識別子はissue番号ベースにし連番採番をやめる.md` の
「JSONキーを改名しなかった理由」を読むこと。**

### 実装上の注意

- **JSONの組み立ては `jq` 1回**。可変長のファイル一覧は `--arg` / `--argjson` ではなく標準入力から
  読ませる（`.claude/rules/shell-script-style.md`「大きなJSONを`--argjson`/`--arg`等の
  コマンドライン引数としてjqへ渡さない」）。2種類のリストは `@@CBC-SPLIT@@` という区切り行で
  1本の入力に連結する（制御文字を使うと、シェルのコマンド文字列へ混ざったとき目視できないため）。
- **`if ! cmd; then ... $? ...` の形で終了コードを読まない**。bashは `!` で反転済みの値を返すため、
  `merge-tree` の「1＝コンフリクト有り」が0として読まれる（issue #46の実装中に実際に踏み、
  検知が常に「コンフリクト無し」になった）。`cmd || status=$?` の形で受ける。
- 出力は最後に `tr -d '\r'` を通す（Windowsネイティブjqが行末へCRを付与する。
  `.claude/rules/shell-script-style.md`「文字コード」）。
- 単体テストから純粋関数だけをsourceで再利用できるよう、`main` の呼び出しは
  `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` でガードする（`update-handoff-progress.sh` と同じパターン）。

## 影響範囲

### issue #46（新規追加）

| ファイル | 変更内容 |
|---|---|
| `.claude/scripts/src/check-base-conflicts.sh` | 新規。本仕様の実装 |
| `tests/test_check_base_conflicts.sh` | 新規。純粋関数（`ddr_number_to_reply` / `find_duplicate_ddr_numbers`）の単体テスト |
| `.claude/skills/resolve-conflict/SKILL.md` | 新規。本スクリプトの結果を受けてコンフリクトを解消する手順 |
| `.claude/skills/issue-mr-flow/SKILL.md` | flow-id 5-2として検知・解消ステップを新設（旧5-2→5-3、旧5-3→5-4。全39→40ステップ）。「defaultブランチとのコンフリクト検知・解消」節を追加 |
| `.claude/skills/commit/SKILL.md` / `.claude/rules/git-workflow.md` / `.claude/rules/docs-workflow.md` | コミットを行うflow-idの一覧を `5-2` → `5-3` へ更新。ステップ数を40へ更新 |
| `.claude/docs/spec/issue-mr-workflow.md` | ステップ数を40へ更新 |
| `.gitignore` | `index.jsonl` の除外理由コメントが参照するDDR番号を `0024` → `0025` へ修正（issue #36の改番時に更新漏れしていた。本issueが対象とする「改番時の参照更新漏れ」の実例） |

### issue #88（PR作成後の追従監視からの繰り返し実行）

| ファイル | 変更内容 |
|---|---|
| （本スクリプト） | 変更なし。監視から繰り返し呼ばれる用途に既存の設計がそのまま使えることを確認した |
| `.claude/docs/spec/check-base-conflicts.md` | 本ファイル。「未決定事項・懸念点」のhookに関する記述を、監視での繰り返し実行と整合する形へ更新し、本エントリを追加 |

### issue #67（判定軸の違うスクリプトの並存）

| ファイル | 変更内容 |
|---|---|
| （本スクリプト） | **変更なし。** 「衝突するか」という判定軸も、fetchの失敗を `git fetch origin "$base" >/dev/null 2>&1 \|\| true` で握りつぶす扱いも維持する |
| `.claude/docs/spec/check-base-conflicts.md` | 本ファイル。本エントリと、下記の相互参照を追加 |

**「衝突しないこと」と「最新であること」は別である。** 本スクリプトの `hasConflict` が偽でも、
ベースブランチ側でルール・仕様**だけ**が追記された場合は衝突もDDR識別子の重複も起きないため、
作業ブランチが遅れている事実は検知できない。この空白は、作業の開始・再開時に「遅れているか」
（behindコミット数）を見る `check-base-sync.sh`（`.claude/docs/spec/check-base-sync.md`）が
埋める。**本スクリプトの結果だけを見て「最新である」と判断しないこと。**

**本スクリプトが fetch の失敗を `|| true` で握りつぶしているのは意図的であり、バグではない。**
本スクリプトによるコンフリクト検知は flow-id 5-1 で必ずもう一度通るため、fetch漏れによる
取りこぼしは後段で拾われる。一方 `check-base-sync.sh` は検知そのものが目的で後段に同じ検知が
無いため、あちらだけは終了コードを `fetchOk` としてJSONへ出している（差を付けた理由の詳細:
`.claude/docs/ddr/i0067-01-作業開始時のベースブランチ追従確認は専用スクリプトで検知しユーザー確認を挟む.md`）。
**どちらかへ揃えようとする前に、このDDRを読むこと。**

### issue #133（DDR識別子のissue番号ベース化）

| ファイル | 変更内容 |
|---|---|
| `.claude/scripts/src/check-base-conflicts.sh` | `ddr_number_to_reply` → `ddr_identifier_to_reply`、`find_duplicate_ddr_numbers` → `find_duplicate_ddr_identifiers` へ改名し、`^(i[0-9]+-[0-9]{2})-` を受け付けるようにした。**JSON出力のキー名は据え置き**。`--help` の出力を行番号直書き（`sed -n '2,30p'`）からコメントブロックの自動抽出（`awk`）へ変更した（コメント増減で範囲が黙ってずれるため） |
| `.claude/scripts/test/test_check_base_conflicts.sh` | 関数名の追従に加え、新方式単独・新旧混在・不正形式（枝番1桁/3桁・枝番なし・大文字 `I`・接頭辞 `issue`）のケースを追加（`passed=28 failures=0`） |
| `.claude/docs/spec/check-base-conflicts.md` | 本ファイル。「検知2」を識別子ベースの記述へ更新し、本エントリを追加 |
| `.claude/rules/markdown-frontmatter.md` | 「DDRの識別子」節を新設 |
| `.claude/rules/docs-workflow.md` | ドキュメント運用表のDDR行 |
| `.claude/docs/README.md` | DDR一覧をissue番号の数値順へ並べ替え、`i00` の説明を追加 |
| `.claude/skills/resolve-conflict/SKILL.md` | 類型AをA-1（旧形式の連番）／A-2（同一issueの枝番衝突）へ分割 |
| `.claude/skills/issue-mr-flow/SKILL.md` | 監視の類型A行・flow-id 5-1 節の説明 |

**既存の連番DDR（`0003`〜`0060` の56件）はすべて新方式へ改番した。** 当初は「改番しない」
（新旧2方式の併存）で決着していたが、ユーザーの判断で全件改番へ変更した（経緯は
DDR i0133-01「全件改番へ方針を変えた経緯」）。対応issueを特定できなかった13件には予約番号
`i00`（`i0000-01`〜`i0000-13`）を振っている。過去のコミットメッセージの引用・changelogエントリ・
単体テストの `0027-…` フィクスチャは、**当時の事実の記録**であるため書き換えていない。

## 未決定事項・懸念点

- **DDR以外の識別子付きリソースは対象外**。現状このリポジトリで対象になるのはDDRのみのため。
  将来 `docs/adr/` 等を追加した場合は `ddrDirs` へ加えれば同じ判定が効く（ただし
  `ddr_identifier_to_reply` が受け付ける2形式のいずれかに命名を合わせる必要がある）。
- **「両ブランチが同じ内容の変更を別の書き方で行った」種類のsemantic conflictは検知できない**
  （例: 同じルールを別の節へ書いた）。これは機械的に判定できないため、`resolve-conflict`
  スキルの類型C・Eとして人間の判断へ委ねる。
- **hookによる自動実行はしていない**。push検知hookで毎回走らせる案もあったが、pushのたびに
  `git fetch` を伴う判定を挟むのはコストに見合わず、push検知hookはコマンド文字列の部分一致で
  誤発火する既知の問題も抱えていた（`.claude/rules/git-workflow.md`「push検知hookの誤検知」）。
  実行タイミングは**手順として明示する**方式を採る（flow-id 5-1、およびPR作成後の追従監視。
  下記）。

  **issue #53でhookスクリプト側の判定はコマンド位置ベースになり、誤発火の理由の大半は
  解消した**（[command-position.md](command-position.md) を参照）。
  ただし**判断の結論は変わらない**。自動実行しない主たる理由は `git fetch` のコストであり、
  誤発火はそれに添えた副次的な理由だったためである。加えて `.claude/settings.json` の
  `if` フィルタは変更しておらず、そちらの照合規則は未解明のまま残っている。
- **本スクリプトはPR作成後の追従監視から繰り返し呼ばれる**（issue #88）。作業ツリーを変更せず、
  引数なしで何度でも実行でき、結果を終了コードではなく `hasConflict` で返す設計は、この繰り返し
  実行にそのまま使える（スクリプト側の変更は不要だった）。監視の手順・自動解消の線引き・停止条件は
  `.claude/skills/issue-mr-flow/references/base-branch-followup.md`「PR作成後のdefaultブランチ追従（監視）」節、
  経緯は `.claude/docs/ddr/i0088-01-PR作成後のdefaultブランチ追従は並行手順として定義し自動解消は一意に決まる類型に限る.md` を参照。
