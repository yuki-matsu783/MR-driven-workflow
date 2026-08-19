---
title: 【設計反映】PR作成後の追従監視をspec/DDRへ反映
type: log
description: issue #88の個別反映計画。追従監視の方針と却下案をDDR 0039として記録し、issue-mr-workflow・check-base-conflictsの2つのspecとDDR一覧へ反映する
tags: [plan, ddr, spec, conflict]
keywords: [設計反映, DDR0039, issue-mr-workflow, check-base-conflicts, 追従監視, 却下案, 影響範囲]
---

# 【設計反映】PR作成後の追従監視をspec/DDRへ反映

対象issue: #88 ／ 全体作業計画: `plans/issue88-pr-base-branch-monitoring.md` ／
直前の個別作業計画: `plans/【設計】【実装】PR作成後のdefaultブランチ追従監視.md`

`【AIアセット反映】` を併記していないのは、AIアセット（`.claude/skills/` `.claude/rules/`
`.claude/agents/`）への反映がissue #88の成果物そのもので、フェーズ3で完了しているため。
本フェーズでは正史（spec）と意思決定ログ（DDR）への反映だけを行う。

## 反映対象

| # | ファイル | 内容 |
|---|---|---|
| 1 | `.claude/docs/ddr/0039-PR作成後のdefaultブランチ追従は並行手順として定義し自動解消は一意に決まる類型に限る.md`（新規） | 背景・決定・却下した案 |
| 2 | `.claude/docs/spec/issue-mr-workflow.md` | 「PR作成後のdefaultブランチ追従（issue #88）」節を追加し、「影響範囲」へ本issueのエントリを追加 |
| 3 | `.claude/docs/spec/check-base-conflicts.md` | 「未決定事項・懸念点」の「hookによる自動実行はしていない」を、監視での繰り返し実行と整合する形へ更新。「影響範囲」へ本issueのエントリを追加 |
| 4 | `.claude/docs/README.md` | DDR一覧へ0039を追加 |

## DDR 0039 に書く内容

### 決定

1. 追従監視は**flow-idを持たないフェーズ横断の並行手順**として定義する（1-3で開始、5-4/クローズで停止）。
2. **flow-id 5-2 は残し、「最終ゲート」として位置づけ直す**（監視は実行環境・セッションに依存するため）。
3. 実行環境別の手段を決め打ちにする（web: `subscribe_pr_activity` + `send_later`／
   ローカル: `/resolve-conflict` の手動実行）。
4. **自動解消の線引きは「解消方法が一意に決まるか」**で行う（類型A/B/D は自動、Cは条件付き自動、
   Eは人間へ）。DDR 0029 の決定6（必ず承認を取る）を**監視モードに限って**緩和する。
5. 監視状態は `HANDOFF.md` のヘッダ1行と `resume` の報告項目で引き継ぐ（セッション依存への手当て）。
6. 自動解消でも `commit` スキル経由のコミットと Step 5 の検証は省略しない。

### 却下する案（理由つきで記録する）

- 新しいflow-idとして挿入し以降を繰り下げる
- flow-id 5-2 を廃止して監視だけにする
- GitHubの "Update branch"（`mcp__github__update_pull_request_branch`）で自動追従する
- PostToolUse / SessionStart hook で自動チェックする
- CI（GitHub Actions）でdefaultブランチのマージ時に全PRを追従させる
- 常時rebase運用へ変更する
- そもそも衝突しにくい構造へ変える（DDR連番の廃止・changelogのファイル分割）
- 検知結果をキャッシュして差分があるときだけ通知する

### DDR 0029 の扱い

`status: superseded` にはしない。決定6が無効化されるのは監視モードに限られ、DDR 0029 全体は
引き続き有効であるため（`.claude/rules/markdown-frontmatter.md`「DDRのstatus」は全体が置き
換わった場合のための仕組み）。新DDR側から明示的に「どの決定をどの範囲で緩和したか」を書く。

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が新規DDRを取り込むこと
- DDR番号 0039 が空き番号であること（`ls .claude/docs/ddr/`）と、flow-id 5-2 の
  `check-base-conflicts.sh` で `hasDuplicateDdrNumber` が偽であること
- 単体テスト `.claude/scripts/test/test_*.sh` が通ること
