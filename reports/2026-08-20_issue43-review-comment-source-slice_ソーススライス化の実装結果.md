---
title: issue #43 作業結果 — レビューコメント出力のソーススライス化（実装・テスト）
type: report
description: diffHunk廃止・正規化JSON化・断面ソースのスライス化の実装内容と、検証結果
tags: [report, implementation, vcs, review]
keywords: [Provider, 正規化JSON, スライス, バイト上限, フォールバック, 単体テスト, 場所不明, session-start]
---

# 作業結果: レビューコメント出力のソーススライス化

個別作業計画: `plans/【実装】【テスト】レビューコメント出力のソーススライス化.md`
調査結果: `reports/2026-08-20_issue43-review-comment-source-slice_レビューコメント出力仕様の調査.md`
全体作業計画: `plans/issue43-review-comment-source-slice.md`（issue #43）

## 結論

**issue #43 の受け入れ条件1〜5・7を実装で満たした**（6=DDRはフェーズ4）。全単体テストが
`failures=0` で通り、実測でスライスのバイト数が **8,971B → 最大2,051B** に収まった。

## 変更内容

| ファイル | 追加 | 削除 |
|---|---|---|
| `.claude/scripts/src/vcs/Github.sh` | `github_normalize_review_threads`（純粋）／`github_get_mr_review_threads`／`github_read_file_at_ref` | `github_get_mr_unresolved_comments` |
| `.claude/scripts/src/vcs/Gitlab.sh` | `gitlab_normalize_discussions`（純粋）／`gitlab_get_mr_review_threads`／`gitlab_read_file_at_ref` | `gitlab_format_discussion_notes`／`gitlab_get_mr_unresolved_comments` |
| `.claude/scripts/src/vcs/Provider.sh` | `truncate_bytes_to_reply`（純粋）／`slice_source_lines`（純粋）／`read_file_at_ref`／`read_source_at_ref_to_reply`／`build_review_source_slices`／`format_review_comments`（純粋）／`get_mr_review_threads` | 旧 `get_mr_unresolved_comments` のディスパッチ |
| `.claude/scripts/test/test_vcs_provider.sh` | 上記純粋関数のテスト（`passed` 153 → **177**） | 旧 `gitlab_format_discussion_notes` のテスト |

差分規模: 4ファイル / +833 / -113。

## 受け入れ条件との対応

| # | 受け入れ条件 | 実装 | 検証 |
|---|---|---|---|
| 1 | diffHunk除去・行番号付きソーススライス | GraphQLクエリから `diffHunk` を削除。`slice_source_lines` が `>>> 12 \| ...` 形式で出力 | `grep -rn diffHunk .claude/*.sh` は説明コメント1件のみ。テスト「出力にdiffHunkの見出しが残っていない」 |
| 2 | スライスはスレッド単位で1回 | `format_review_comments` がスレッドの全コメントを出した**後**に1回だけ置く | テスト「ソーススライスはスレッドにつき1回だけ出る」（返信2件のスレッドで `--- source ` が1回） |
| 3 | 行数とバイト数の両方で上限制御 | `REVIEW_SOURCE_CONTEXT_LINES`（既定10）／`REVIEW_SOURCE_MAX_BYTES`（既定2000） | 下記「実測」 |
| 4 | `line` が null なら `originalLine` | `github_normalize_review_threads` が解決し、断面も `originalCommit.oid` へ切り替える | テスト「lineがnullならoriginalLineとoriginalCommit.oidへ落ちる」 |
| 5 | GitLabも `path`/`line`/`sha` を出し同じ後段ロジックを通る | `gitlab_normalize_discussions` が `position` から3つを解決。整形は共通の `format_review_comments` | テスト9件（【未検証】: 実機のGitLabでは動かしていない） |
| 7 | ローカルにblobが無い場合のフォールバック | `read_source_at_ref_to_reply` の4段階 | 下記「フォールバックの実測」 |

## 実測

### バイト上限（`.claude/rules/docs-workflow.md` へ指摘を付けた場合）

| 指摘行 | 変更前（diffHunk相当の ±10行素の切り出し） | 変更後（ソースブロック全体） |
|---|---|---|
| 5 | 684 | 875 |
| 12 | 3,133 | 1,331 |
| 20 | 8,394 | 1,208 |
| 30 | **8,971** | 1,979 |
| 40 | 2,143 | **2,051** |

**最大 8,971B → 2,051B。ばらつきも13.1倍 → 2.3倍に縮んだ。** 変更後が2,000Bを僅かに超えるのは、
上限が**スライス本文**にかかり、`--- source <path> @ <sha> ---` の見出し行（約50B）が別枠のため。
行番号の接頭辞（`>>> 30 | `）ぶん、短い切り出しでは変更前より増えることがある（line=5 の
684B → 875B）が、**上限が効く側で1/4以下に落ちる**ので目的は達している。

### フォールバックの実測

| ケース | 出力される見出し |
|---|---|
| ローカルにblobがある | `--- source AGENTS.md @ 7895107 ---` |
| shaが解決できない | `--- source AGENTS.md @ HEAD (断面 0000000 を取得できず現HEADを表示) ---` |
| shaが空（位置はあるが断面不明） | `--- source AGENTS.md @ HEAD (断面が不明なため現HEADを表示) ---` |
| ファイル自体が無い | ソースブロックを出さず、コメント本文だけを出す |
| バイト上限で削った | `--- source ... @ 7895107 (バイト上限により切り詰め) ---` |
| outdatedスレッド | `--- source ... @ 2222222 (outdated) ---` |

**プロバイダのファイル取得API経由（段階2）はこの環境では発火させられなかった**
（`gh`/`glab` が無く、`get_vcs_access_mode` が `mcp` を返すため段階2が丸ごとスキップされる）。
コードパスは実装済みだが【未検証】である。

### テスト

```
$ bash .claude/scripts/test/test_vcs_provider.sh
passed=177 failures=0
```

`.claude/scripts/test/` の12スクリプトすべてを実行し、全て `failures=0`（合計 passed=667）。
`bash -n` も3ファイルで通る。

## 設計上、計画から変えた点

### 1. `read_source_at_ref` を「標準出力へ返す」から「`REPLY` へ返す」へ変えた

計画では標準出力へ返す設計だったが、**戻り値が3つある**（内容・表示用のref・縮退の注記）ため
`content="$(read_source_at_ref ...)"` と書くとコマンド置換がサブシェルをforkし、
関数内で設定した `REVIEW_SOURCE_REF` / `REVIEW_SOURCE_NOTE` が呼び出し元へ伝わらない。
実装中に `REVIEW_SOURCE_REF: unbound variable` で表面化した。
`read_source_at_ref_to_reply` へ改名し、`REPLY` へ返す形にした
（`.claude/rules/shell-script-style.md` の「`REPLY` へ返す」は性能を動機に書かれているが、
**戻り値が複数ある場合にも同じ形が要る**という点は明文化されていない）。

### 2. `(場所不明)` を出すのをやめた

issue #43 以前のGitHub実装は `path` が null のとき ` (場所不明)` と出していた。共通化すると
**GitLabのMR全体へのコメント（`position` を持たないのが正常）にもこの表示が付く**ため、
位置が無いときは何も出さないことにした。GitHubのレビュースレッドは常に `path` を持つため、
この分岐は事実上発火しておらず、GitHub側の実挙動は変わらない。

### 3. 中間表現に base64 を使わなかった

計画時は「スライス本文をbase64でTSVの1フィールドへ入れる」ことを考えていたが、
**スレッド数に比例して `base64` をforkする**（`.claude/rules/shell-script-style.md`
「外部プロセス起動のコスト」）。`\037`（unit separator）で始まるヘッダ行＋本文行という
レコード形式にし、jq側で `startswith("\u001f")` で分解することで、**jqの起動は
`build_review_source_slices` 全体で2回**（位置の取り出しと組み立て）に収まった。
ループ内で起動するのは `git` のみで、同じ `(sha, path)` はメモ化して1回だけ読む。

## 副次的に直った不具合

**GitLabリポジトリで未解決レビューコメントが常に0件と表示されていた問題**が直った。
行頭ラベルが GitHub `[review unresolved …]` / GitLab `[unresolved …]` と非対称で、
`.claude/hooks/session-start.sh:169` の `^\[review unresolved threadId=` にGitLab側が
一致しなかったため。整形が1箇所へ寄ったことで、この種の非対称が構造的に起きなくなった。

## やり残し・持ち越し

- **GitHub GraphQL のフィールドを実機で確認していない**（`gh` がこの環境に無い）。実装は
  `// null` / `// empty` で null 耐性を持たせてあり、フィールドが返らなくてもソース無しへ
  縮退するだけで壊れない。`gh` のある環境で `comments` を1回実行すれば確認できる。
- **GitLab側も実機検証できない**（remoteがGitHubのみ）。issue #128 の実機検証の対象へ、
  本issueで追加した `gitlab_normalize_discussions` / `gitlab_get_mr_review_threads` /
  `gitlab_read_file_at_ref` を加えてもらうのが自然。
- **MCP経路ではソーススライスを作れない**（`mcp__github__pull_request_read` が `line` も sha も
  返さない。GitHub MCPサーバー側の制約）。`mcp_tool_hint` にその旨を追記した。
- 設計ドキュメント（spec / DDR / SKILL.md）への反映はフェーズ4で行う。

## 反映結果（flow-id 4-6）

### 設計反映

| ファイル | 内容 |
|---|---|
| `.claude/docs/spec/issue-mr-workflow.md` | 提供関数表の書き換え（`get_mr_review_threads` / `read_file_at_ref` を追加）、内部ヘルパーの説明の更新、**新節「レビューコメントのソーススライス」**、`## 影響範囲` への issue #43 エントリ追記 |
| `.claude/docs/ddr/0059-…` | 断面の選び方（コメント時点のsha優先・現HEADへ縮退）。却下案4件（常に現HEAD／取れなければ出さない／ファイル全体／diffHunk＋行番号）を含む |
| `.claude/docs/README.md` | DDR一覧へ 0059 を追記 |
| `.claude/docs/spec/adversarial-review.md` | 現在の状態を説明する箇所の関数名、投稿したスレッドにソーススライスが添えられる旨 |

**過去changelog（`## 影響範囲` 配下の issue #48 / #42 / #77 の節）は書き換えていない。**
`gitlab_format_discussion_notes` という名前がそこに残るのは当時の記録として正しい
（`.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は…changelogを対象に
含めない」と同じ理由）。反映対象9箇所のうち5箇所がこれに該当した。

### AIアセット反映

| ファイル | 内容 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | `comments` 手順2の出力説明（「該当diff」→「ソーススライス」）と、**見出しの注記の読み方**（`(断面 … を取得できず現HEADを表示)` が出たら断面がずれている）。MCP対応表へ「MCP経路ではスライスを作れない」注記 |
| `.claude/rules/shell-script-style.md` | 「`REPLY` へ返す形が要るのは性能のためだけではない」（戻り値が複数ある関数）、「ソースコードへ生の制御文字を書かない」 |

### 検証

- `.claude/scripts/test/` の12スクリプト全てで `failures=0`。
- `bash .claude/scripts/src/extract-frontmatter.sh .` → `failed=0`。
  `search-frontmatter.sh --type ddr --text 断面` で 0059 が引ける。
- DDR 0059 の相互リンクを `os.path.exists` で機械検査（当初 DDR 0027 のファイル名を誤っており、
  この検査で気づいて修正した）。
- 追跡ファイル全件について、生の制御文字（NUL・`\037`）が無いことをバイト数比較で確認。
- 新節・changelogエントリの挿入位置の前後3行を目視し、空行の重複・不足が無いことを確認。
