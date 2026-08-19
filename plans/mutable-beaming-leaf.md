# issue #55 全体作業計画: remote URLのホスト抽出の二重実装を解消する

/ issue: [#55](https://github.com/yuki-matsu783/MR-driven-workflow/issues/55)
/ ブランチ: `feature-55-unify-remote-url-host-extraction`
/ PR: [#56](https://github.com/yuki-matsu783/MR-driven-workflow/pull/56) (Draft)

## Context

`.claude/scripts/src/vcs/Provider.sh` に、remote URLからホスト部を切り出す実装が**2つ独立して**存在する。

| 関数 | 追加 | 実装方式 | 返すもの |
|---|---|---|---|
| `provider_from_remote_url`（[Provider.sh:132](../.claude/scripts/src/vcs/Provider.sh)） | issue #45 | パラメータ展開のみ | プロバイダ名。ホストを小文字化 |
| `parse_repo_slug`（[Provider.sh:195](../.claude/scripts/src/vcs/Provider.sh)） | issue #34 | `sed` 2回 ＋ `jq` 1回 | `{host, owner, repo, path, url}` のJSON。小文字化なし |

scheme除去・認証情報（`user@`）除去・ポート除去・scp形式（`git@host:path`）対応という**同じ規則が別々の
方法で二重に書かれている**。片方だけ直すともう片方とずれる。issue #45とissue #34が並行して進んだ結果
生まれた重複で、**実害が出ているわけではなく予防的な整理**である。

## 調査結果（実測。フェーズ2は省略する）

### 判定結果は1点を除いて一致している

10種類のURL形式で両者のホスト抽出結果を突き合わせた。

| URL | `parse_repo_slug.host` | パラメータ展開 |
|---|---|---|
| `https://github.com/o/r.git` / `git@github.com:o/r.git` / `ssh://git@github.com/o/r.git` | 一致 | 一致 |
| `ssh://git@ghe.example.com:2222/o/r.git`（ポート付き） | 一致 | 一致 |
| `http://localhost:8929/root/demo.git` | 一致 | 一致 |
| `https://user@gitlab.com:8080/foo/b@r.git`（パスに`@`） | 一致 | 一致 |
| `https://gitlab.example.com/g/sub/r.git`（ネストnamespace） | 一致 | 一致 |
| `https://gitlab.com/github-mirror/x.git` | 一致 | 一致 |
| `git@aslead-git.corp.local:foo/bar.git` | 一致 | 一致 |
| **`https://GitHub.COM/O/R.git`** | **`GitHub.COM`** | **`github.com`** | 

**差分は大文字小文字の扱いだけ。** `parse_repo_slug` はパスに `@` を含むURLでも
`[^/@]` という文字クラスのおかげで誤爆しておらず、現状の挙動そのものに不具合は無い。

### コストの差は大きい

git bash（MSYS）の外部プロセス起動は約95ms/回（`.claude/rules/shell-script-style.md`）。

| 実装 | 実測（20回） | 1回あたり |
|---|---|---|
| `parse_repo_slug`（`sed`×2 + `jq`×1） | 5706ms | **285ms** |
| パラメータ展開のみ | 35ms | 実質ゼロ |

`get_repo_slug` は `.claude/hooks/session-start.sh:91`（**セッション開始のたび**）と
`get_repo_url` のMCPフォールバック経路から呼ばれるため、この削減はそのまま体感に効く。

### `provider_from_remote_url` 側の制約は維持が必須

12個のディスパッチャがいずれも `case "$(get_provider)" in` の形で呼ぶ。コマンド置換はサブシェルを
作るためグローバル変数によるメモ化が効かず、ここでプロセス起動を増やすと全ディスパッチに波及する
（詳細: `.claude/docs/ddr/0028-プロバイダ判定はremote-URLのホスト部でgithub以外をgitlabとみなす.md`）。
**統合後も追加forkゼロを保つ。**

## 方針: 純粋関数 `split_remote_url` を新設し、両者がそれを使う

remote URLを**ホスト部とパス部に分解する**パラメータ展開のみの関数を1つ作り、
`provider_from_remote_url` と `parse_repo_slug` の双方がそれを呼ぶ。

```
split_remote_url <url>
  → REPLY_HOST（小文字化済みホスト名）
  → REPLY_PATH（owner/repo 形式。.git・末尾スラッシュ除去済み）
```

戻り値を標準出力ではなくグローバル変数へ返すのは、呼び出し側がコマンド置換を使わずに済ませるため
（`.claude/rules/shell-script-style.md`「ホットパスの小さなヘルパー関数は…`REPLY` へ返す」）。
値が2つあるので `REPLY` ではなく `REPLY_HOST` / `REPLY_PATH` とする。

### 分解のアルゴリズム

scp形式（`git@host:o/r.git`）とポート付きURL（`host:2222/o/r.git`）は、`:` の後ろが**数字だけかどうか**で
区別する。これがパラメータ展開だけで書ける唯一の分岐点になる。

```
1. scheme 除去           "${url#*://}"
2. 認証情報 user@ 除去    最初の "/" より前に "@" がある場合のみ "${rest#*@}"
                          （パスに "@" を含むURLで誤爆させないため）
3. ホスト部の切り出し     first="${rest%%/*}"
   3a. ":" を含まない      → host=first, path="${rest#*/}"（"/" が無ければ path=""）
   3b. ":" の後が数字のみ  → ポート。host="${first%%:*}", path="${rest#*/}"
   3c. それ以外            → scp形式。host="${first%%:*}", path="${rest#*:}"
4. host を小文字化        "${host,,}"
5. path の .git・末尾スラッシュ除去
```

**エラーは投げない。** ホスト名が空だった場合の扱いは呼び出し側に委ねる
（`provider_from_remote_url` は現在どおり終了コード1、`parse_repo_slug` は現在どおり空のまま
JSONを返す）。こうすることで**両関数の外部から見た振る舞いを変えずに済む**。

### 小文字化を `parse_repo_slug` にも適用する（唯一の振る舞い変更）

現在 `parse_repo_slug` はホストの大文字小文字をそのまま返す。統合すると小文字化されるため、
`https://GitHub.COM/O/R.git` に対する `.host` と `.url` が変わる。

- ホスト名はDNS上case-insensitiveであり、小文字化はURLの正規化として安全。
- 消費側は `.owner` / `.repo` / `.url` のみを使う（`session-start.sh:91`、`get_repo_url`）。
  **`.owner` / `.repo` は小文字化しない**ので、リポジトリ名の大文字は保たれる。
- 既存テストはすべて小文字ホストのため影響なし。**新規テストで明示的に固定する。**

## フェーズ3: 実装・テスト

個別作業計画は `plans/【実装】【テスト】ホスト抽出の共通化.md` にまとめる（実装とテストを同時に書き、
1回で合意を取る）。

- `Provider.sh` に `split_remote_url` を新設する。
- `provider_from_remote_url` を「`split_remote_url` を呼び `REPLY_HOST` で判定する」形へ書き換える
  （判定規則そのもの＝`aslead` → gitlab ／ `github` → github ／ それ以外 → gitlab、および
  空ホスト時の終了コード1は**変更しない**）。
- `parse_repo_slug` を「`split_remote_url` を呼び、`REPLY_PATH` から owner/repo を分けて `jq` で
  JSON化する」形へ書き換える。`sed` 2回が消えて外部プロセス起動は **3回 → 1回**になる。
- `tests/test_vcs_provider.sh` に `split_remote_url` の直接テストを追加する。既存の
  `parse_repo_slug` 6件・`provider_from_remote_url` 15件は**1件も削らない**（統合で振る舞いが
  変わっていないことの証拠になるため）。追加するのは次の観点。

  | 観点 | 例 |
  |---|---|
  | ホストとパスの同時取得 | `https://github.com/o/r.git` → host=`github.com`, path=`o/r` |
  | scp形式 | `git@github.com:o/r.git` → host=`github.com`, path=`o/r` |
  | ポート付き | `ssh://git@ghe.example.com:2222/o/r.git` |
  | パスに`@` | `https://user@gitlab.com:8080/foo/b@r.git` |
  | 大文字ホスト | `https://GitHub.COM/O/R.git` → host=`github.com`, path=`O/R`（**パスは小文字化しない**） |
  | パス無し | `https://github.com` → path が空 |
  | ネストnamespace | `https://gitlab.example.com/g/sub/r.git` → path=`g/sub/r` |

- **テスト内で `get_provider` を上書きしている箇所（issue #34の `mcp_tool_hint` テスト）より後ろに
  新規テストを置かない。** ファイル冒頭のコメントにこの注意書きが既にある。

## フェーズ4: 反映

`【設計反映】` と `【AIアセット反映】` は分けて実施する（flow-id 4-6〜4-9 を2セット）。

### 設計反映

- `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表直後の内部ヘルパーの段落に
  `split_remote_url` を追記し、`provider_from_remote_url` の説明を新しい関係へ更新する。
- 同「影響範囲」へ**新規エントリを追記**する（過去のchangelogは書き換えない）。
- 小文字化の統一を「決定済み事項」へ1項目として記録する（issueの受け入れ条件
  「外部から見た振る舞いが変わる場合はspecへ記録する」に対応）。
- **DDRは新規作成しない見込み。** DDR 0028が判定規則とfork制約の意思決定を既に記録しており、
  本issueはその制約を守ったままの内部整理であって、新しい意思決定を含まないため。
  レビューで必要と判断されれば作成する。

### AIアセット反映

現時点で予定している具体項目は無く、**「反映なし」で終える可能性がある**（無理に書かない）。

## 変更対象ファイル

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `split_remote_url` 新設、`provider_from_remote_url` と `parse_repo_slug` を書き換え |
| `tests/test_vcs_provider.sh` | `split_remote_url` のテストを追加（既存テストは削らない） |
| `.claude/docs/spec/issue-mr-workflow.md` | 内部ヘルパーの段落・決定済み事項・影響範囲（フェーズ4） |
| `HANDOFF.md` | flow-idが進むごとに更新 |

## 検証方法

1. `bash -n .claude/scripts/src/vcs/Provider.sh` / `bash -n tests/test_vcs_provider.sh`
2. `bash tests/test_vcs_provider.sh` → `failures=0`（現在36 → 44前後）。
   **既存36件が1件も落ちないことが「振る舞いを変えていない」ことの主たる根拠**になる。
3. **統合前後で出力が一致することの直接確認**: 統合前の `parse_repo_slug` の出力を10種類のURLについて
   保存しておき、統合後の出力と突き合わせる（大文字ホストの1件のみ意図的に差が出る）。
4. **このリポジトリ（GitHub）で退行が無いこと**: `get_provider` → `github`、
   `get_repo_slug | jq -r '.owner, .repo'`、`get_mr_for_branch` が従来どおり動く。
5. **コスト削減の実測**: `parse_repo_slug` を20回呼ぶ時間が 5706ms から縮むことを確認する
   （`jq` 1回ぶんは残るため、おおむね1/3程度が目安）。
6. `.claude/hooks/session-start.sh` のMCP経路は `gh` 不在環境でしか通らないため、
   **`get_repo_slug` を直接呼ぶ確認で代替する**（CLIをアンインストールしての検証は行わない）。

## 守るべき条件・触ってはいけない範囲

- **`provider_from_remote_url` の1回あたりのプロセス起動数をゼロに保つ。** コマンド置換・パイプ・
  外部コマンドを増やさない（DDR 0028の制約）。
- **判定規則そのものを変えない。** `aslead` → gitlab ／ `github` → github ／ それ以外 → gitlab の
  順序と結果は現状維持。`aslead` を `github` より前に置くことにも意味がある。
- **`parse_repo_slug` の返すJSONのキー・構造（`{host, owner, repo, path, url}`）を変えない。**
  `session-start.sh`・`get_repo_url`・`issue-create` / `issue-mr-flow` の各SKILL.mdが依存している。
- **既存テストを削らない・弱めない。**
- **DDR 0028・0027は変更しない。**
- `Github.sh` / `Gitlab.sh` は変更しない。

## 未確定事項

- 統合によって「fork数ゼロ」と「JSON出力」の双方を満たせないと判明した場合は、**統合せずクローズ
  してよい**（issue #55の受け入れ条件）。現時点の設計では両立できる見込みだが、実装で行き詰まった
  場合はこの選択肢を取る。
- DDRを新規作成するかはフェーズ4のレビューで判断する（現時点では不要と考えている）。
