---
title: post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（全体作業計画）
type: plan
description: issue #149。post-issue-create-notice.shのCLI経路検知を部分一致からCommandPosition.shによるコマンド位置判定へ差し替える全体作業計画
tags: [hook, command-position, issue-149]
keywords: [post-issue-create-notice, CommandPosition, コマンド位置, 誤検知, issue-mr-flow]
---

# post-issue-create-notice.shの検知をコマンド位置ベースにして誤検知を減らす（全体作業計画）

- issue: #149
- ブランチ: `claude/post-issue-notice-detection-xleu14`
- PR: https://github.com/yuki-matsu783/MR-driven-workflow/pull/179

## 目的

`.claude/hooks/post-issue-create-notice.sh` の `is_issue_create_call` が持つCLI経路の判定
（`[[ "$command" == *create-issue.sh* ]]`、単純な部分一致）を、issue #53 で他の3本のhook
（`block-direct-git-commit.sh` / push検知2本）に導入済みの「コマンド位置での判定」
（`.claude/hooks/lib/CommandPosition.sh`）へ差し替える。ファイル名を含むだけの `cat` / `grep` /
ドキュメント編集・コメント・ヒアドキュメント本文では発火せず、実際にスクリプトが実行された
ときだけ発火するようにする。

## 変更対象

- `.claude/hooks/lib/CommandPosition.sh`: 「`git <サブコマンド>` がコマンド位置にあるか」に
  特化した既存の `command_invokes_git_subcommand` とは別に、「任意のスクリプト（basename）が
  コマンド位置で実行されるか」を判定する新しい公開関数を追加する（issue #149の受け入れ条件
  「任意のスクリプト名を判定する形が必要なら、ライブラリ側へ公開関数を足す」）。
- `.claude/hooks/post-issue-create-notice.sh`: `is_issue_create_call` のCLI経路判定を新関数へ
  差し替え、`block-direct-git-commit.sh` と同じ3段ガード（bashバージョン・`source`の成否・
  `declare -F`）で読み込み、満たさない場合は従来の部分一致へ縮退する。
- `.claude/scripts/test/test_command_position.sh`: 新しい公開関数の単体テストを追加する。
- `.claude/scripts/test/test_post_issue_create_notice.sh`: issue #149の受け入れ条件にある
  発火/非発火ケースを追加する。
- `.claude/docs/spec/command-position.md`: 「未決定事項・懸念点」から4本目（本hook）に
  関する記述を、対応済みの旨へ更新する。
- `.claude/docs/spec/issue-mr-workflow.md`: 「既知のトレードオフ」節を、コマンド位置判定へ
  移行した旨へ更新する。

## 方針

issue #147（`block-direct-git-commit.sh` のコマンド位置化）と同じ構造をそのまま踏襲する。
`CommandPosition.sh` の正規化（`normalize_shell_command_to_reply`）はコマンド共通の前処理
（クォート・コメント・ヒアドキュメント本文をプレースホルダへ潰す）であり、そのまま再利用できる。
新規に書くのは「正規化後の文字列を走査してスクリプトのbasenameを探す」部分のみで、これは
既存の `_cp_scan_tokens`（`git <サブコマンド>` 専用）と並ぶ形で追加する（`git`固有の
グローバルオプション読み飛ばしロジックは不要な一方、インタプリタ経由の実行
（`bash <path>` 形式）への対応が新たに要る）。

`is_issue_create_call` のMCP経路判定（`tool_name` の固定文字列比較）は変更しない
（issue本文が「MCP経路も同様に扱う」と求めているのは、CLI経路と同じ堅牢さを持たせる
という意味であり、`tool_name` の完全一致は元々誤検知の余地が無いため）。

前置フィルタ（`raw_hints_at_issue_create`、issue #159）は変更しない。この関数は
`is_issue_create_call` の**超集合**として設計されており、CLI経路判定を部分一致から
コマンド位置判定へ差し替えても、部分一致でマッチする入力はすべてコマンド位置判定でも
マッチしうる集合に含まれる（コマンド位置判定は部分一致の対象を絞り込むだけで、新しい語形を
拾うようにはならないため）。念のため、既存テストの
「create-\\issue.shのようにバックスラッシュで分割されていても通過する」等のケースが
新しい判定本体に対しても成立することを実装後に確認する。

## フェーズ2〈調査〉

**実施しない。** 参考実装（issue #147 / `block-direct-git-commit.sh` /
`.claude/hooks/lib/CommandPosition.sh` / `.claude/docs/spec/command-position.md`）を
全体作業計画の作成前に読み込み済みで、変更対象・方針を確定できたため。追加の調査で
覆る不確実性は残っていない（`CommandPosition.sh` は既に他3本で実運用されている共通基盤で
あり、新規に検証すべき外部要因が無い）。

## フェーズ4〈反映〉

- **設計反映**: `.claude/docs/spec/command-position.md`「未決定事項・懸念点」の該当行と、
  `.claude/docs/spec/issue-mr-workflow.md`「既知のトレードオフ」節を、対応済みの内容へ更新する。
  新しいDDRは起票しない見込み（issue #53のDDR `i0053-01` の対象範囲を広げる形の変更であり、
  新規の意思決定ではなく既存方針の適用であるため）。ただし実装中に却下案が出た場合はDDRの
  要否を再検討する。
- **AIアセット反映**: 作業中に気づいたルール・スキルの不備があれば反映する（見込みは無いが
  枠は残す）。
- **実装反映**: フェーズ3のレビュー往復で解消しきれない不具合が出た場合に扱う（見込みは無い）。

## やらないこと（スコープ外）

- MCP経路（`mcp__github__issue_write` の `method` 判定）の変更。
- 他の3本のhook（`block-direct-git-commit.sh` / push検知2本）への追加変更。
- `raw_hints_at_issue_create`（前置フィルタ）自体のロジック変更（超集合性の再確認のみ行う）。
- `.claude/settings.json` の `if` フィルタの変更（本hookには元々 `if` フィールドが無い）。

## 検証

- `.claude/scripts/test/test_command_position.sh` と
  `.claude/scripts/test/test_post_issue_create_notice.sh` が、追加したケースを含めて
  `passed=N failures=0` で通ること。
- issue #149 の受け入れ条件（発火する/しないケース、`CommandPosition.sh` の再利用、
  3段ガードでの縮退、spec更新の2点）をすべて満たすこと。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応 |
|---|---|
| 発火しないこと: `cat`/`grep`/ドキュメント編集、コメント内言及、ヒアドキュメント本文内言及 | 新関数のテストケースとして追加 |
| 発火すること: 単体実行、`cd … && …`、改行区切りの2行目、`bash <パス>` 形式 | 同上 |
| `CommandPosition.sh` を再利用し、任意のスクリプト名を判定する公開関数を足す | `command_invokes_script`（仮称）を追加 |
| bashバージョン・`source`の成否・`declare -F`の3段ガード | `block-direct-git-commit.sh` と同じ形を移植 |
| `test_post_issue_create_notice.sh` へケース追加、全件 `failures=0` | 実施 |
| `command-position.md`「未決定事項・懸念点」と `issue-mr-workflow.md`「既知のトレードオフ」の更新 | フェーズ4で実施 |

## 比較検討した案

- **`_cp_scan_tokens` を汎用化し `git` 専用ロジックと共有する案**: 却下。`git`側は
  グローバルオプション（`-C`/`-c`等、値を1つ取るものと取らないものが混在）の読み飛ばしを
  持つが、スクリプト名判定側にはそれが無い。共通化すると分岐が増えて両方読みにくくなる一方、
  コード量の削減幅は小さい。既存コードも「hookごとに前置フィルタを個別実装する」設計判断
  （issue #159）を取っており、多少の重複より局所性を優先する方針に合わせる。
- **CLI経路の検知自体を諦め、MCP経路（`create-issue.sh`実行後にissueが実際に作られたかを
  別途確認する等）へ寄せる案**: 却下。CLI経路が使える環境（gh/glab CLIあり）でも検知が必要
  という受け入れ条件と矛盾する。
