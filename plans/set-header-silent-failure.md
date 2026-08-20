---
title: 全体作業計画 — set-headerの無言成功を無くしHANDOFFヘッダ表記を確定する
type: plan
description: issue #66（update-handoff-progress.sh の set-header が対象行を書き換えられなくても無言で成功する）の全体作業計画
tags: [plan, update-handoff-progress, handoff]
keywords: [set-header, 無言の失敗, HANDOFF, ヘッダ行, 表記ゆらぎ, Draft PR, 終了コード, テンプレート, issue66, issue140]
---

# 全体作業計画 — set-headerの無言成功を無くしHANDOFFヘッダ表記を確定する

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)

## この計画の位置づけ

本ファイルは flow-id 1-4 の**全体作業計画**（issue＝ブランチにつき1つ）である。個別の調査計画・
作業計画・反映計画は `plans/【*.md` として別ファイルへ作る。

**planツール（Planモード）を使わずWrite/Editで作成している。** 本セッションは Claude Code on the
web の非対話セッションで、Planモードの承認（flow-id 1-5）を待てないためである。ユーザーからは
「#66 をPR作りながら対応して。敵対的レビューしながら進めて」という着手指示を受けている。
人間のレビュー往復（flow-id 2-3/2-8・3-3/3-8・4-3/4-8）は待てないため、代替として
`adversarial-review` スキルによる敵対的レビューを挟む。

**ブランチ名が `.mrworkflow.json` の `branchPrefixTemplate`（`feature-{issue}-{slug}`）に従って
いない**のは、ハーネスが `claude/set-header-silent-failure-p3izl0` を作業ブランチとして
指定しているためである（ハーネス側の指定を優先する。`.claude/rules/git-workflow.md`
「ハーネスがPR作成を制限する環境での扱い」と同じ考え方）。

## 背景

`update-handoff-progress.sh set-header --pr` は、HANDOFF.mdのPR行が `- Draft PR:` 表記だと
どの行にもマッチせず、**ファイルを1バイトも変えないまま終了コード0を返す**。同じスクリプトの
`mark-done` は対象行が見つからなければ明示して失敗するのに、`set-header` だけが一貫していない。

根本には「**HANDOFF.mdのヘッダ行の正しい表記がどこにも定義されていない**」という問題がある。
リポジトリにコミットされているHANDOFF.mdの空テンプレートにヘッダ行の雛形が無く、タスクごとに
AIエージェントが書き起こしているため、表記が揺れる。

## フェーズ2〈調査〉

**実施する。** 個別調査計画は `plans/【調査】set-headerの無言成功とヘッダ表記の実態.md`。

調べること:

1. `cmd_set_header` が無言で成功する条件を、実物と同じ形のHANDOFF.mdで再現する。
2. HANDOFF.mdのヘッダ行が実際にどう書かれてきたか（表記・並び順・**ファイル内の位置**）を
   git履歴から確認する。
3. ヘッダ行を扱う他の箇所（`set_loop_header_in_lines` の挿入位置判定、`cleanup-task.sh` の
   テンプレート、`issue-mr-resume` エージェントの現在地サマリ）が、同じ前提を置けているか。
4. issue #140（`mark-skip` がループ範囲の一部だけを `[-]` にできる）を本issueへ取り込むか、
   別issueのまま残すかを判断する材料を揃える。

## フェーズ3〈作業〉

**実施する。** 個別作業計画は `plans/【実装】【テスト】set-headerの失敗検知とヘッダ表記の確定.md`。

想定している変更（確定は調査結果を見てから個別作業計画で行う）:

- `.claude/scripts/src/update-handoff-progress.sh`
  - `set-header` で指定した項目のうち、対応するヘッダ行が見つからなかったものがあれば
    **書き戻さずに**エラー終了する。
  - ヘッダ行の探索範囲を「ヘッダブロック」に限定し、本文中の引用行を書き換えないようにする。
- `.claude/scripts/src/cleanup-task.sh`
  - `HANDOFF_TEMPLATE` へヘッダ行の雛形を追加する。
- `.claude/scripts/test/test_update_handoff_progress.sh` / `test_cleanup_task.sh`
  - 上記の挙動を検証するケースを追加する。既存ケースは `failures=0` のまま通す。

## フェーズ4〈反映〉

**必ず通る。** 反映対象は flow-id 4-1 で洗い出す。現時点での候補（確定した反映内容ではない）:

- `.claude/docs/spec/update-handoff-progress.md`（ヘッダ行の正しい表記・`set-header` のエラー条件）
- `.claude/docs/spec/cleanup-task.md`（テンプレートの変更）
- `.claude/rules/docs-workflow.md`（HANDOFF.mdのヘッダ表記）
- `.claude/docs/ddr/i0066-01-*.md`（採用案と却下案）＋ `.claude/docs/README.md` のDDR一覧（生成）

個別反映計画は `plans/【設計反映】〜.md` と `plans/【AIアセット反映】〜.md` に分ける
（原則併記しない）。反映するものが無ければ、その旨を書いて残りをスキップする。

## フェーズ5〈クローズ〉

- flow-id 5-1: `check-base-conflicts.sh` でdefaultブランチとのコンフリクトを検知する。
- flow-id 5-2: 関連issue（#140 が最有力）へ承認を得てから通知する。
- flow-id 5-3: `cleanup-task.sh` で `plans/` `worklog/` `reports/` を片付ける。
- flow-id 5-4: commit・リモートへ反映し、Draftを解除する。**マージへは進まない。**

## この計画で決めないこと（スコープ外）

- **issue #140（`mark-skip` のループ範囲伝播）の実装**。本issueでは「#66 と #140 をまとめるか」の
  結論を出して記録するところまでとし、`mark-skip` の挙動そのものは変えない（判断の根拠は
  フェーズ2の調査結果に書く）。
- **`- 追従監視:` 行を `set-header` の対象へ加えること**。現行仕様は「手で書き換える」であり、
  変更するなら別issueで扱う。
- 進捗状態をJSON/YAML等の構造化データへ移す設計（DDR i0020-01 で却下済み）。

## 検証

```bash
bash .claude/scripts/test/test_update_handoff_progress.sh
bash .claude/scripts/test/test_cleanup_task.sh
for f in .claude/scripts/test/test_*.sh; do bash "$f" >/dev/null || echo "NG: $f"; done
bash -n .claude/scripts/src/update-handoff-progress.sh
```

加えて、**修正前のスクリプトへ戻すと新規テストが失敗すること**を確認する（テストが実装追認に
なっていないことの確認。`REVIEW-POINTS.md`「検証コマンドが、異常があるときに本当に検出できるか」）。
