---
title: issue #43 調査結果 — レビューコメント出力仕様（diffHunk廃止・断面ソースのスライス化）
type: report
description: 正規化JSONのキー・断面の取得可否・上限制御の既定値を確定させるための調査結果
tags: [report, investigation, vcs, review]
keywords: [diffHunk, GraphQL, reviewThreads, originalLine, isOutdated, discussions, position, shallow, blob, バイト上限, スライス]
---

# 調査結果: レビューコメント取得APIの返却フィールドと断面

個別調査計画: `plans/【調査】レビューコメント取得APIの返却フィールドと断面.md`
全体作業計画: `plans/issue43-review-comment-source-slice.md`（issue #43）

## 結論（先に3行）

1. **正規化JSONは GitHub / GitLab 双方から埋められる。** 位置は `path` + `line` +
   `originalLine` + `isOutdated`、断面は `sha` の1キーで表現できる。
2. **断面のblobはこの環境（shallow clone・depth 190）でもローカルで解決できた。** ただし
   保証は無いため、`git cat-file -e` での事前判定＋フォールバック段階が要る。
3. **行数だけでは上限にならないことを実測で確認した。** 同一ファイルの ±10行で
   **684B〜8,971B（13.1倍）** の開きがあった。バイト上限の併用は必須である。

## E. 既存実装の棚卸し（変更範囲の確定）

### 出力を消費している箇所

| 消費者 | 依存している形 | 今回の変更での扱い |
|---|---|---|
| `.claude/hooks/session-start.sh:168-170` | `grep -oE '^\[review unresolved threadId=[^ ]+'` で**行頭の書式に依存**して未解決件数を数える | **書式の先頭 `[review unresolved threadId=...]` は変えない** |
| `.claude/agents/issue-mr-resume.md:49` | 未解決件数の集計（同じ書式） | 同上 |
| `.claude/skills/issue-mr-flow/SKILL.md` `comments` サブコマンド | 出力をそのままユーザーへ提示 | 説明文を「該当diff」→「ソーススライス」へ改める |
| `.claude/docs/spec/adversarial-review.md:301-309` | 投稿したスレッドが `path:line` 付きで取れることを前提にしている | 前提は維持される（位置情報はむしろ増える） |

### 見つかった非対称（issue本文の項目5に加えて判明）

**GitHub と GitLab で行頭のラベルが違う。**

| 実装 | 行頭 |
|---|---|
| `github_get_mr_unresolved_comments` | `[review unresolved threadId=...]` |
| `gitlab_format_discussion_notes` | `[unresolved threadId=...]`（`review ` が無い） |

`session-start.sh` は `^\[review unresolved threadId=` で数えているため、**GitLabリポジトリでは
未解決レビューコメントが常に0件と表示される**。整形を共通化すれば副次的に解消する。

### 変更対象外

- **MCP経路（`mcp__github__pull_request_read`）は今回の変更の影響を受けない。** `Provider.sh` を
  通らず、AIがツールを直接呼ぶため。ただし後述のとおりMCP経路は**行番号もshaも返さない**ため、
  そもそもソーススライスを作れない。この差はSKILL.mdの対応表へ注記する。

## A. GitHub の返却フィールド

### A-1. MCP経路（`method="get_review_comments"`）の実測

PR #37 に対して実行した結果（`perPage=2`）:

```json
{"review_threads":[{"id":"PRRT_kwDOT7UgWc6aS9t8","is_resolved":true,"is_outdated":true,
 "is_collapsed":true,"comments":[{"body":"...","path":"plans/【設計反映】...md",
 "author":"yuki-matsu783","created_at":"...","updated_at":"...","html_url":"...#discussion_r3808796698"}],
 "total_count":2}],"totalCount":1}
```

**スレッド単位に `is_resolved` / `is_outdated` / `is_collapsed` があり、コメントには `path` と
`html_url` がある。一方 `line` / `original_line` / commitのshaは1つも返らない。**

- 判明した制約: **MCP経路ではソーススライスを作れない**（位置が行まで特定できず、断面のshaも無い）。
  issue #43 が作るのはCLI経路の出力仕様であり、MCP経路は「`path` までは分かる」という現状の
  ままになる。SKILL.mdの対応表へこの差を明記する。
- issue本文の「本リポジトリの既存スレッドは全件 `line=null` / `isOutdated=true`」は、
  `is_outdated: true` が返っている点で裏付けられた。

### A-2. GraphQL のフィールド（【未検証】: この環境に `gh` が無く実行できない）

GitHub GraphQL の公開スキーマ上、必要なフィールドは揃っている。

| 型 | フィールド | 用途 |
|---|---|---|
| `PullRequestReviewThread` | `id` | `threadId` |
| | `isResolved` | 未解決の絞り込み |
| | `isOutdated` | 断面が古い旨の明示 |
| | `path` | スライス対象のパス |
| | `line` / `originalLine` | 指摘行（`line` が null なら `originalLine`） |
| | `startLine` / `originalStartLine` | 複数行指摘の開始行（範囲指摘の下限に使える） |
| | `subjectType` | `FILE`（ファイル全体への指摘）の判別 |
| `PullRequestReviewComment` | `author { login }` / `body` / `url` | 現行どおり |
| | `commit { oid }` | `line` を使うときの断面 |
| | `originalCommit { oid }` | `originalLine` を使うときの断面 |
| | ~~`diffHunk`~~ | **クエリから除去する** |

**この表は公開スキーマに基づく設計であり、この環境では実行して確認していない（【未検証】）。**
実装は「フィールドが null で返っても壊れない」形（`// empty` でのフォールバック）にする。

### A-3. diffHunkの重複（issue本文の項目2）の裏取り

`.claude/scripts/src/vcs/Github.sh` の該当箇所は次の構造になっている。

```
| $t.comments.nodes[]        ← スレッド内の各コメントで展開
| ( ... ヘッダ行 ... )
  + (if .diffHunk then ("\n--- diff ---\n" + .diffHunk) else "" end)
```

`diffHunk` を出しているのは**コメント単位の展開の内側**であり、スレッド単位ではない。
返信が N 件付いたスレッドでは **同じdiffHunkが N 回出る**。コード読解で確認した
（issue本文のPR #37 での2回重複と整合する）。

## B. GitLab の `position`（【未検証】: remoteがGitHubのみ）

`.claude/scripts/src/vcs/Gitlab.sh` の既存実装と GitLab discussions API の仕様から、
`position` は次のキーを持つ。

| キー | 用途 |
|---|---|
| `head_sha` | **断面のsha**（MRのソースブランチ側のcommit） |
| `base_sha` / `start_sha` | 差分の基準。スライスには使わない |
| `new_path` / `new_line` | 追加・変更行への指摘 |
| `old_path` / `old_line` | 削除行への指摘（`new_line` が無い） |
| `position_type` | `text` / `image` 等 |

既存実装は `new_line` → `old_line` の順に見て `path:line` を組み立てている。この判定はそのまま
正規化JSONの `path` / `line` の決定に流用できる。**削除行への指摘は `old_path` を `head_sha` で
切ると存在しない**ため、その場合は `base_sha` を断面として扱うか、ソース無しへ縮退させる。

GitLabは解決状態が **note単位**（`resolvable` / `resolved`）である一方、GitHubは**スレッド単位**
（`isResolved`）である。正規化ではスレッド単位へ寄せ、GitLab側は「discussion内のいずれかのnoteが
未解決ならスレッドは未解決」とみなす（現行の実装がnote単位に出力しているのを、スレッド単位の
判定へ集約する形になる）。

## C. 断面の取得可否（実測）

### C-1. この環境は shallow clone である

```
$ git rev-parse --is-shallow-repository
true
$ wc -l .git/shallow
10 .git/shallow
$ git rev-list --count HEAD
190
```

`check-base-sync.sh` の `isShallow: true` と一致する。

### C-2. それでも過去commitのblobは引けた

```
$ for c in 4b8fb20 d48b698 846c536 88e03b9; do git cat-file -e "$c:.claude/rules/docs-workflow.md"; done
→ 全て OK
```

**shallow cloneでも、履歴の切断点より新しいcommitのblobはローカルに存在する。** レビューコメントが
指す断面は「そのPRのcommit」であり、通常は切断点より新しいため、**実際にはローカルで解決できる
ケースが大半**と考えられる。ただし保証は無い（古いPRの再開・`--depth 1` の環境など）。

### C-3. 判定と失敗の形

存在しないshaを指定すると `git cat-file -e` が非0で終わる。

```
$ git cat-file -e "0000...0000:.claude/rules/docs-workflow.md"
fatal: path '...' exists on disk, but not in '0000...0000'
```

**「ワーキングツリーに存在するか」と「その断面に存在するか」は別**であり、メッセージも
そのことを明示している。`git show` の成否ではなく `git cat-file -e <sha>:<path>` を
事前判定に使うのが確実（`git show` は失敗時にも標準エラーへ出力するため、握りつぶしが要る）。

### C-4. 確定したフォールバック段階

| 段階 | 手段 | 出力での明示 |
|---|---|---|
| 1 | `git cat-file -e <sha>:<path>` が成功 → `git show <sha>:<path>` | なし（既定） |
| 2 | プロバイダ別ファイル取得API<br>GitHub: `gh api repos/{owner}/{repo}/contents/<path>?ref=<sha>`（`.content` はbase64）<br>GitLab: `glab api projects/:id/repository/files/<encoded>/raw?ref=<sha>` | なし（同じ断面のため） |
| 3 | `git show HEAD:<path>` | **`（断面 <sha> を取得できず現HEADを表示）`** を添える |
| 4 | すべて失敗 | **`（ソース取得不可）`** を添える。コメント本文だけは必ず出す |

段階4を必ず用意するのは、**ソースが取れないことでコメント本文まで落ちてはならない**ため。

## D. 上限制御の実測

### D-1. 行数指定は制御にならない

`.claude/rules/docs-workflow.md`（131行 / 18,441B、1行あたり平均141B）で、指摘行を変えて
±10行のバイト数を測った。

| 指摘行 | 切り出し範囲 | バイト数 |
|---|---|---|
| 5 | 1-15 | **684** |
| 12 | 2-22 | 3,133 |
| 20 | 10-30 | 8,394 |
| 30 | 20-40 | **8,971** |
| 40 | 30-50 | 2,143 |

**同じファイル・同じ ±10行でも 684B〜8,971B と 13.1倍の開きがある。** このファイルの最長行は
1,387B あり、表形式の行が数本入るだけで上限を突き抜ける。issue本文の 5,107B という実測値も
この範囲に収まる（測った行が違うだけ）。

比較として、1行が短いシェルスクリプト（`.claude/scripts/src/vcs/Provider.sh`）では ±10行が
984B〜1,038B に収まった。**ファイル種別によって1桁違う。**

### D-2. 既定値の決定

| 項目 | 既定値 | 根拠 |
|---|---|---|
| 前後行数 | **10行**（指摘行を含め最大21行） | 指摘行の意図を読むのに前後10行あれば足りることが多い。issue本文の議論もこの水準 |
| バイト上限 | **2,000B** | 上表で最大の 8,971B を約1/4.5へ抑える。Provider.sh 級（約1,000B）は無傷で通り、
markdown の表・長文行を含む箇所だけが切り詰められる。スレッド10件でも約20KBに収まる |

- 切り詰めは**指摘行を中心に前後を均等に削る**（指摘行が落ちては意味が無い）。
- 切り詰めた場合はその旨を出力へ明示する（`（バイト上限により切り詰め）`）。
- 既定値は環境変数（`REVIEW_SOURCE_CONTEXT_LINES` / `REVIEW_SOURCE_MAX_BYTES`）で上書き可能にする。
  `.mrworkflow.json` へは置かない（他リポジトリへ移植したときに書き換えたくなる値ではなく、
  その場のコンテキスト事情で一時的に変えたい値であるため）。

### D-3. 現行との比較（見積り）

| | 現行（diffHunk） | 新（±10行 / 2,000B上限） |
|---|---|---|
| 1スレッドあたり | 342B 〜 9,189B（issue本文の実測。24倍の開き） | **最大 2,000B**（予測可能） |
| 返信N件のスレッド | diffHunkが **N回** 重複 | スライスは **1回** |
| 行番号 | 無い（`@@` から自力で数える） | **絶対行番号付き** |
| 指摘行より後ろ | 取れない | **取れる** |

## 確定した正規化JSONのスキーマ

プロバイダ層（`github_get_mr_review_threads` / `gitlab_get_mr_review_threads`）が返す形。

```json
{
  "threads": [
    {
      "threadId": "PRRT_kwDO...",
      "isResolved": false,
      "isOutdated": true,
      "path": ".claude/scripts/src/vcs/Github.sh",
      "line": 91,
      "sha": "4b8fb20f6b1d0324367ceeda280a31dc4d016732",
      "comments": [
        {"author": "yuki-matsu783", "body": "...", "url": "https://.../#discussion_r..."}
      ]
    }
  ],
  "comments": [
    {"author": "yuki-matsu783", "body": "...", "url": "https://.../#issuecomment-..."}
  ]
}
```

- `line` は「`line` が非nullならそれ、nullなら `originalLine`」を解決済みの値とする
  （**プロバイダ層で解決し、共通層はどちらだったかを知らない**）。どちらも無ければ `null`。
- `sha` も同様にプロバイダ層で解決済み（GitHub: `commit.oid` / `originalCommit.oid`、
  GitLab: `position.head_sha`）。取れなければ `null` で、共通層は段階3へ落ちる。
- `path` が無いスレッド（位置不明）は `path: null`。現行の `(場所不明)` 出力を維持する。

## 出力書式（確定案）

```
[review unresolved threadId=PRRT_kwDO... .claude/scripts/src/vcs/Github.sh:91 url=https://...] yuki-matsu783: ここは重複しています

--- source .claude/scripts/src/vcs/Github.sh @ 4b8fb20 (outdated) ---
    81 |   gh api graphql -F "owner={owner}" ...
    ...
>>> 91 |         + (if .diffHunk then ("\n--- diff ---\n" + .diffHunk) else "" end);
    ...
   101 | }
```

- 行頭の `[review unresolved threadId=...]` は**現行のまま**（`session-start.sh` の集計が依存）。
- ソースブロックは**スレッドにつき1回**、そのスレッドの全コメントを出力した後に置く。
- 指摘行は `>>>` で示し、他行は空白4文字で揃える。
- 断面が現HEADへ落ちた場合は見出しを
  `--- source <path> @ HEAD (断面 <sha> を取得できず) ---` にする。

## 未解決・持ち越し

- **A-2（GraphQLの実フィールド）はこの環境で実行検証できない。** 実装側で null 耐性を持たせ、
  spec には【未検証】と記す。`gh` のある環境で `comments` を1回実行すれば確認できる。
- **B（GitLab）も実機検証できない。** issue #128（ローカルGitLab CEでの13関数の実機検証）の
  対象へ、本issueで追加する関数を加えてもらうのが自然。
- MCP経路が行番号・shaを返さない件は、**GitHub MCPサーバー側の制約**であり本issueでは変えられない。
  SKILL.mdの対応表へ注記するに留める。
