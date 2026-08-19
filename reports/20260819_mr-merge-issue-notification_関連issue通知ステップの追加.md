---
title: 20260819 関連issue通知ステップの追加（issue #86）実施結果
type: report
description: issue #86でadd_issue_commentの新設とflow-id 5-3（マージ前の関連issue通知）の追加を行った実施結果・検証結果の正文
tags: [issue-mr-flow, provider, notification, report]
keywords: [add_issue_comment, flow-id-5-3, 繰り下げ, 41ステップ, MCPフォールバック, require_vcs_cli, 実機検証, DDR-0041, issue-67]
---

# 実施結果: マージ前の関連issue通知ステップの追加（issue #86）

対象: issue #86「マージ前に今回のMRが影響する関連issueを特定し通知するステップを追加する」（2026-08-19）
個別作業計画: `plans/【設計】【実装】マージ前の関連issue通知ステップを追加する.md`

## 結論

issue #86 の受け入れ条件4件のうち**3件を満たし、1件（`add_issue_comment` のCLI経路の実機確認）は
実行環境の制約により未達**である。未達分は spec の「未決定事項・懸念点」へ明示して残した。

| 受け入れ条件 | 結果 |
|---|---|
| `add_issue_comment` が `Provider.sh` / `Github.sh` / `Gitlab.sh` に実装され、GitHub実機で1件投稿できることを確認済み | **一部達成**。3ファイルへ実装済み。実機投稿は**MCP経路で確認済み**（issue #67 へ1件投稿）だが、`gh issue comment` を使う**CLI経路は本環境に `gh` が無いため未検証** |
| SKILL.md の全体フロー表に新flow-idが追加され、`HANDOFF.md` の進捗表と整合している | **達成** |
| ステップ数の記述（SKILL.md / spec / docs-workflow.md）が新しい値へ更新されている | **達成**（40→41） |
| spec の提供関数表・MCPフォールバック対応表が更新されている | **達成** |
| 設計判断がDDRとして記録されている | **達成**（DDR 0041） |

## 実施内容

### 1. `add_issue_comment <issue番号> <bodyFile>` の新設

`add_mr_comment` を流用せず**別関数**として追加した。GitHub実装が `gh pr comment` であり、PR以外の
issueへは物理的に投げられないためである（理由・却下案の詳細はDDR 0041）。

| ファイル | 実装 |
|---|---|
| `Provider.sh` | `require_vcs_cli add_issue_comment` → プロバイダ別ディスパッチ。`mcp_tool_hint` へ1行追加 |
| `Github.sh` | `gh issue comment "$n" --body-file "$file"` |
| `Gitlab.sh` | `glab api "projects/:id/issues/<iid>/notes" -X POST -f "body=..."`（`gitlab_add_mr_comment` と同じREST直叩き方式に揃えた）【未検証】 |

本文は `add_mr_comment` / `set_mr_description` と同じく**ファイル経由**とした。通知本文には差分の
説明が入るため、地の文に `git` と `push` が連続する語が紛れ込むとpush検知hookが誤発火する
（`.claude/rules/git-workflow.md`「push検知hookの誤検知」）。

### 2. flow-id 5-3「関連issueの特定・通知」の新設と繰り下げ

- 新 **5-3**: 関連issueの特定・通知（エージェント。ただし投稿前に `AskUserQuestion` での承認が必須）
- 旧5-3（Draft解除）→ **5-4** ／ 旧5-4（マージ）→ **5-5**
- **全40 → 41ステップ**

SKILL.md へ手順の正となる節「マージ前の関連issue通知（flow-id 5-3）」を新設した。手順は
「差分確認 → AIがキーワードを最大5件抽出 → `search_issues` で候補検索 → 3類型（前提が変わる／
一部が解決される／記述が矛盾する）で判定 → `AskUserQuestion` で承認 → `add_issue_comment` で投稿」。
影響先が無ければスキップしてよく、その場合も「影響先なし」と判断した事実を `HANDOFF.md` へ残す。

節の差し込み位置は、`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」
のルールに従い、直前の節（`## defaultブランチとのコンフリクト検知・解消`）の末尾の地の文の係り先が
変わらないよう、その節の直後（フロー順どおり 5-2 → 5-3）へ置いた。前後3行を目視で確認し、空行が
2つ連続しないこと・次の見出しの直前に空行が1つあることを確認している。

### 3. 副次的に見つかった記述のずれ（あわせて修正）

**spec のMCPフォールバック節が列挙していた `require_vcs_cli` を呼ぶ関数の一覧が古かった。**
「プロバイダ依存の8関数」として `get_issue` / `new_issue` / `new_draft_merge_request` /
`get_mr_unresolved_comments` / `add_mr_thread_reply` / `get_mr_for_branch` / `set_mr_description` /
`add_mr_comment` を挙げていたが、issue #68（`search_issues`）・issue #61（`set_mr_ready`）で
関数が増えた際に更新されておらず、実際には10関数だった。本対応の `add_issue_comment` を含めて
**11関数**へ修正した。

**`set_mr_ready` のコードコメントが flow-id 5-3 のままだった**ため、`Provider.sh` / `Github.sh` /
`Gitlab.sh` の3箇所を 5-4 へ更新した（コードコメントは現在の状態の説明であり、changelogとは
扱いが異なるため更新対象に含めた）。

### 4. 意図的に更新しなかった箇所

`.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は…過去issueごとのchangelogを
対象に含めない」に従い、**point-in-timeの記録である以下は書き換えていない**。

- `.claude/docs/spec/check-base-conflicts.md`「影響範囲 / issue #46」の「旧5-2→5-3、旧5-3→5-4。
  全39→40ステップ」
- `.claude/docs/spec/issue-mr-workflow.md`「影響範囲 / issue #46」および「影響範囲 / issue #61」の
  flow-id 注記（issue #61 の注記は「Draft解除は現在 5-3 である」と書かれているが、当時の記録として
  残す。現在の番号の正は SKILL.md の全体フロー表である）
- `.claude/docs/ddr/*.md` の本文（DDR 0029・DDR 0039 が言及する 5-3 / 5-4 を含む）

## 検証結果

| 検証 | 結果 |
|---|---|
| `bash -n`（変更した4つの `.sh`） | 全て構文OK |
| `bash .claude/scripts/test/test_vcs_provider.sh` | **`passed=98 failures=0`**（`mcp_tool_hint` のテストを2件追加。うち1件は `add_mr_comment` が「PR番号を渡す」ままであることを固定し、`add_issue_comment` と混同しないようにするもの） |
| `require_vcs_cli` のガード（実環境は `gh` 不在） | `add_issue_comment: gh/glab CLIが…存在しないため、CLI経路では実行できません。 代替（MCPフォールバック経路）: mcp__github__add_issue_comment (owner, repo, issue_number=通知先issue番号, body=ファイル内容)` を出力し終了コード1。**期待どおり** |
| プロバイダ別ディスパッチ | `github_add_issue_comment` / `gitlab_add_issue_comment` をスタブへ差し替え、`get_provider` の値に応じて正しい方へ引数（issue番号・ファイルパス）が渡ることを確認 |
| CR混入 | 変更した全ファイルで「除去前後のバイト数が一致」を確認（`grep -c $'\r'` は使わない。`.claude/rules/shell-script-style.md`「テスト」） |
| **MCP経路での実機投稿** | **成功**。issue #67 へ1件投稿し、`https://github.com/yuki-matsu783/MR-driven-workflow/issues/67#issuecomment-5344871722` が返った |

## 新ステップ自体のドッグフーディング結果

本対応の差分に対して、新設した flow-id 5-3 の手順をそのまま実行した。

1. **差分確認**: `git diff --stat`（11ファイル変更・DDR 1件新規）。
2. **キーワード抽出**: 「flow-id」「ステップ番号」「フェーズ5」「Draft解除」「Provider.sh」。
3. **候補検索**: MCP経路（`mcp__github__search_issues`）で #86（自issue・除外）・#61（closed）・#22 が、
   openのissue一覧との突き合わせで #67・#92 が候補に挙がった。
4. **3類型での判定**:

   | issue | 判定 | 理由 |
   |---|---|---|
   | #67 作業開始・再開時のベースブランチ追従確認をフローへ追加する | **前提が変わる** | 新しいフロー用ステップの追加を求めており、フェーズ5の番号（5-1〜5-4 → 5-1〜5-5）と総ステップ数（40→41）が挿入位置・番号設計の前提になる |
   | #61 Provider.shにDraft解除の関数が無い（closed） | 前提が変わる（低優先） | 対象のDraft解除が 5-3 → 5-4 へ再度繰り下がった。closedのため通知価値は低い |
   | #92 全体作業計画には調査・反映フェーズを必ず含める | 該当なし | 対象が flow-id 1-4 と `[-]` の運用で、今回の差分は触れていない |
   | #22 適用要否の判定基準の一元化（closed） | 該当なし | キーワードが一致しただけ |

5. **承認**: `AskUserQuestion` で投稿先と本文を提示し、**#67 のみ承認**を得た。
6. **投稿**: 上表のとおり成功。

**この一連で、手順が実際に回ることと、3類型の判定が「候補を絞る」役割を果たすことを確認できた**
（キーワード一致だけなら5件が候補になるが、判定で1件まで絞られた）。

## 未達・未検証

- **`add_issue_comment` のCLI経路（`gh issue comment` / `glab api`）が実機未検証。** 本セッションの
  実行環境（Claude Code on the web）に `gh`・`glab` のいずれも存在しないため。spec の
  「未決定事項・懸念点」へ項目を追加した。GitLab実装は `gitlab_add_mr_comment`（issue #48で
  GitLab CE 18.5.4に対し実機確認済み）のエンドポイントを `merge_requests` → `issues` へ替えた
  だけだが、issue notes APIのパラメータ名が同じであることの確認は公式APIドキュメントの参照に留まる。
- **`reports/` のHTML版は作成していない。** 本対応の結果は表と手順の列挙であり、複数要素間の
  関連・依存関係が主題ではないため（`canvas-report` スキルの適用対象でもない）。flow-id 3-6 は
  HTMLを「結果を視覚的にまとめる必要があれば」としており必須ではない。
- **人間のレビュー往復（flow-id 3-3/3-4・3-8/3-9・4-3/4-4・4-8/4-9）は非対話的セッションのため
  未実施。** 進捗表の該当ループ範囲は `[]` のまま残している。
