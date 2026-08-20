---
title: 調査結果 フェーズ5の番号繰り下げ範囲と添付APIの実現可能性
type: report
description: issue #111 の調査結果。flow-id繰り下げの波及範囲の分類、GitHub添付APIがこの環境で使えないことの確認、通常コメントの種別識別方針。
tags: [report, research, workflow, attachment]
keywords: [flow-id, 繰り下げ, changelog, 添付API, uploads.github.com, 403, 通常コメント, 署名]
---

# 調査結果: フェーズ5の番号繰り下げ範囲と添付APIの実現可能性（issue #111）

全体作業計画: `plans/mellow-drifting-lantern.md`
個別調査計画: `plans/【調査】フェーズ5の番号繰り下げ範囲と添付APIの実現可能性.md`
実施日: 2026-08-21 / 実行環境: Claude Code on the web（Linux・`gh`/`glab` CLI不在・MCP経路）

## 結論（先に3行）

1. **繰り下げの対象は67件、凍結すべきものは19件**。凍結側の内訳は spec の過去changelog 9件と
   DDR本文 10件で、両方とも `.claude/rules/docs-workflow.md` が一括置換を禁じている対象である。
2. **層3（HTML添付）はこの実行環境では動かない**。`gh` CLI が無くトークンも得られず、MCPにも
   添付ツールが無く、`uploads.github.com` は認証前の時点で403を返す。**この結果自体が
   「層3を任意にする」設計判断の裏付けになる。**
3. **通常コメントの種別識別は、既存の `Claude Codeより（敵対的レビュー）:` の前例に倣えばよい**。
   既存の投稿種別を1つも書き換えずに済む。

---

## 調査1: フェーズ5の番号繰り下げが波及する範囲

### 実行したコマンドと総数

```bash
grep -rn 'flow-id 5-[3-6]' --include=*.md --include=*.sh --include=*.json . | grep -v '^./worklog\|^./plans'
grep -rno 'flow-id 5-[3-6]' --include=*.md --include=*.sh --include=*.json . | grep -v '^./worklog\|^./plans' | wc -l
```

- **マッチ総数: 88件**（`grep -o` によるマッチ単位）
- **該当行数: 86行**（`grep -n` による行単位）。差の2件は、1行に2つの `flow-id` を書いている行
  （`.claude/docs/spec/issue-mr-workflow.md` の changelog 2箇所）である。

以降の件数は**行単位（86行）**で数える。

### 分類結果

| 群 | 行数 | 扱い |
|---|---|---|
| **A: 書き換える**（現在の手順・状態の説明） | **67** | `5-3`→`5-4`、`5-4`→`5-5`、`5-5`→`5-6` |
| **B: 凍結（spec の過去changelog）** | **9** | 一切触らない。新規エントリの追記で対応する |
| **C: 凍結（DDR本文）** | **10** | 本文は触らない。うち該当するものへ frontmatter の `note` を足す |

#### A: 書き換える（67行）

| ファイル | 行数 |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 20 |
| `.claude/rules/docs-workflow.md` | 8 |
| `.claude/rules/git-workflow.md` | 5 |
| `.claude/docs/spec/cleanup-task.md` | 5 |
| `.claude/docs/spec/issue-mr-workflow.md`（1624行目より前のみ） | 4 |
| `.claude/scripts/src/cleanup-task.sh` | 3 |
| `.claude/rules/directory-structure.md` | 3 |
| `index.md` / `.claude/scripts/src/vcs/Provider.sh` / `.claude/rules/markdown-frontmatter.md` / `.claude/docs/spec/extract-frontmatter.md` / `.claude/docs/README.md` | 各2（計10） |
| `reports/REVIEW-POINTS.md` / `.claude/skills/doc-search/SKILL.md` / `.claude/skills/canvas-report/SKILL.md` / `.claude/scripts/test/test_update_handoff_progress.sh` / `.claude/scripts/src/vcs/Gitlab.sh` / `.claude/scripts/src/vcs/Github.sh` / `.claude/scripts/src/update-handoff-progress.sh` / `.claude/docs/spec/update-handoff-progress.md` / `.claude/docs/spec/create-commit.md` | 各1（計9） |

#### B: 凍結（spec の過去changelog、9行）

すべて `.claude/docs/spec/issue-mr-workflow.md` の **`## 影響範囲`（1624行目）以降**にある。
該当行: 2199, 2213, 2346, 2347, 2586, 2601, 2602, 2605, 2670。

**境界の確認方法**（後続の作業者が再現できるように残す）:

```bash
grep -n '^## 影響範囲\|^## 未決定事項' .claude/docs/spec/issue-mr-workflow.md
# → 1624:## 影響範囲 / 3108:## 未決定事項・懸念点
```

他のspec4件（`cleanup-task.md` 151・`extract-frontmatter.md` 211・`update-handoff-progress.md` 138・
`create-commit.md` 139）も `## 影響範囲` を持つが、**今回のヒットはいずれもその行より前**にあり、
すべて群Aである。`.claude/rules/*.md` と各 `SKILL.md` にはchangelog節が無い（`grep -l` で0件）。

#### C: 凍結（DDR本文、10行）

| DDR | 行数 | 現在の記述 | 今回の変更で新たに陳腐化するか |
|---|---|---|---|
| `i0041-01-PR_MR作成はAIエージェントに委ねマージのみ明示指示を必須にする.md` | 5 | `5-3`=Draft解除・`5-4`=マージ | **しない**（issue #112 の時点で既に陳腐化済み） |
| `i0086-01-マージ前の関連issue通知は….md` | 2 | `5-3`=関連issue通知 | **しない**（同上。現在は 5-2） |
| `i0117-01-削除済み追跡ファイルの除外は….md` | 1 | `5-4`=削除をコミットする手順 | **する**（→ 5-5） |
| `i0113-01-issue-mr-flow対象ブランチでは….md` | 1 | `5-3`=リセット（片付け） | **する**（→ 5-4） |
| `i0028-01-flow-id5-1の後片付けは….md` | 1 | **frontmatter の `note`**「片付けは現在 flow-id 5-3」 | **する**（→ 5-4） |

### 設計への反映

- **`i0028-01` の1件は frontmatter の `note` であり、本文ではない。** `.claude/rules/markdown-frontmatter.md`
  は frontmatter の後追い更新を明示的に許しているため、**この1件は書き換える**（群Aへ移す）。
  よって実際の置換対象は **68行**、DDR本文の凍結は **9行**になる。
- 新たに陳腐化する `i0117-01` `i0113-01` には `note` を足す。**`i0041-01` `i0086-01` には足さない**
  （今回の変更が原因ではなく、issue #112 由来の既存の陳腐化であるため。ここで巻き取ると、
  今回のPRの差分に「今回の変更と無関係な修正」が混ざる）。**ただし陳腐化していること自体は事実**
  なので、本レポートに記録して次のタスクへ渡す。
- **一括 `sed` を全体へ当てない。** 群Bを含む `issue-mr-workflow.md` は、1624行目より前だけを
  対象にするか、4箇所を個別に直す。`.claude/rules/docs-workflow.md` は issue #47 で同種の事故
  （過去changelogまで書き換えた）を記録しており、その再発を避ける。
- 置換後の検証は、`.claude/rules/docs-workflow.md` が指定する
  `git diff <分岐点SHA> -- .claude/` の**削除行**を読む形で行う。

---

## 調査2: GitHub添付APIの実現可能性

### 確かめたこと

| # | 確認内容 | 実行したこと | 結果 |
|---|---|---|---|
| 1 | `gh` CLI の有無 | `command -v gh glab curl` | **`gh`・`glab` とも無し**。`curl` のみ（`/usr/bin/curl`） |
| 2 | トークンの有無 | `env` でトークン系の環境変数名のみ列挙し、`${#GH_TOKEN}` で長さを確認 | `GH_TOKEN` / `GITHUB_TOKEN` は存在するが**いずれも14文字**。GitHubのトークン形式（`ghp_`＋36文字＝40文字、`github_pat_` は82文字以上）のどれにも一致しない |
| 3 | MCPに添付ツールがあるか | `ToolSearch` で `github attachment upload asset file` を検索 | 返ったのは `create_or_update_file` / `push_files` / `delete_file` / `get_file_contents` / Actions系のみ。**PR/issueへの添付に相当するツールは無い** |
| 4 | `uploads.github.com` への到達性 | `curl -sS -o /dev/null -w '%{http_code}' -X POST 'https://uploads.github.com/user-attachments/assets?name=probe.txt'` | **403** |
| 5 | 比較対照（API本体への到達性） | `curl -sS -o /dev/null -w '%{http_code}' https://api.github.com` | **200** |

### 確かめられなかったこと

- **403の発信元**。エージェントプロキシが弾いたのか、GitHub側が弾いたのかは切り分けられていない。
  レスポンスヘッダを読もうとしたが、この環境の権限判定によりコマンドが実行できなかった。
  したがって「**この環境では層3が動かない**」とは言えるが、「**GitHubのこのエンドポイントが
  壊れている／PATでは通らない**」とまでは言えない。
- **実際のアップロードの成否**。未ドキュメントの内部エンドポイントへ実ファイルを投げるのは
  可否確認に必要な範囲を超えるため、意図的に行っていない（個別調査計画の「やらないこと」）。
- **GitLab側（`POST /projects/:id/uploads`）の実挙動**。このリポジトリのremoteはGitHubで、
  GitLab実機が無い（issue #127 が実機検証を担当）。**公式APIとして文書化されている**ことのみ確認した。

### 設計への反映

- **層3を必須にできない**ことが、この環境の実測で裏付けられた。issue #111 が挙げていた
  「未ドキュメントAPIは予告なく壊れる」という将来リスク以前に、**現時点で既に動かない環境が
  存在する**（このリポジトリの主要な作業環境そのもの）。
- したがって `upload_attachment` は、**「失敗が正常系のひとつ」として設計する**。呼び出し側は
  非0終了を受けてスキップし、警告だけ出してフローを続ける。成功を前提にした分岐を書かない。
- 上表 #1〜#3 は「**認証情報が無いので試すまでもなく失敗する**」という、`Provider.sh` の既存の
  `require_vcs_cli` ガードと同じ形の失敗である。`upload_attachment` の GitHub 実装は、
  ネットワークへ出る前にこのガードで落ちるのが自然な振る舞いになる。
- **1環境・1バージョンの観測である**ことを明記して仕様へ転記する（`reports/REVIEW-POINTS.md` の
  「測った環境が結論に添えられているか」）。ローカルの git bash 環境（`gh` CLI あり）では
  結果が変わりうる。

---

## 調査3: PR/MR通常コメントの種別識別

### 現状（実ファイルからの引用）

`add_mr_comment`（＝PR/MRの**通常コメント**）で投稿されるものは、issue #111 のコメントが挙げた
3種類ではなく、**4種類**ある。

| # | 種別 | 本文1行目 | 出どころ |
|---|---|---|---|
| 1 | チャットで受けたレビュー判断の記録 | `Claude Codeより: チャットで受けたレビュー判断の記録（flow-id 3-9・レビュー2回目）` | `SKILL.md:713`（DDR `i0050-01`） |
| 2 | スレッドを持たない指摘への対応記録 | 規定なし（`Claude Codeより:` のみ） | `SKILL.md:462` 付近（DDR `i0109-01`） |
| 3 | **対応工数レポート** | `Claude Codeより: 自動投稿（post-push-usage-report.sh による集計。…）` | `spec/issue-mr-workflow.md:1191` |
| 4 | 最終統括レポートのサマリ | **今回設計する** | issue #111 |

**#3 は issue #111 のコメントが数えていなかった種別である。** 種別識別の設計は、3種ではなく
4種を前提にする必要がある。

### 既にある前例

インラインコメント側には**括弧付きの種別ラベル**の前例がある。

```
Claude Codeより（敵対的レビュー）:
```

- `.claude/scripts/src/vcs/Github.sh:373` / `Gitlab.sh:364`（実装）
- `.claude/docs/spec/adversarial-review.md:292`（仕様）
- `.claude/scripts/test/test_vcs_provider.sh:622,668`（テストが文字列を固定している）

### 設計への反映

- **統括レポートのサマリは `Claude Codeより（最終統括レポート）:` で始める。** 既存の
  `Claude Codeより（敵対的レビュー）:` と同じ形であり、**新しい規約を発明しない**。
- **既存の #1〜#3 は書き換えない。** 書き換えると `SKILL.md` の複数箇所・spec・既に投稿済みの
  コメントに波及するのに対し、得られるのは表記の統一だけである。**#4 だけが括弧付きラベルを
  持てば、読み手は「これは統括レポートか、それ以外か」を1行目で判別できる**（issue #111 の
  コメントが求めていたのはこの判別である）。
- `SKILL.md` へ**通常コメントの種別一覧表**（上表の#1〜#4）を置く。1行目の書式が種別ごとに
  違うこと自体を、探さずに分かる形で1箇所へ集約する。

---

## 次フェーズ（作業）への引き継ぎ

| 項目 | 決まったこと |
|---|---|
| 置換対象 | 68行（群A＋`i0028-01` の `note`）。`issue-mr-workflow.md` は1624行目より前のみ |
| 凍結対象 | spec changelog 9行・DDR本文 9行。`i0117-01` `i0113-01` へ `note` を足す |
| 層3の設計 | 失敗を正常系として扱う。`require_vcs_cli` 相当のガードで早期に非0終了する |
| サマリの1行目 | `Claude Codeより（最終統括レポート）:` |
| 積み残し | `i0041-01` `i0086-01` の flow-id 参照は issue #112 由来で既に陳腐化しているが、今回は触らない |
