---
title: 【設計】【実装】PR作成後のdefaultブランチ追従監視
type: log
description: issue #88の個別作業計画。追従監視をフェーズ横断の並行手順として定義し、issue-mr-flow/resolve-conflict/git-workflow/issue-mr-resumeの4アセットへ反映する設計と手順
tags: [plan, conflict, workflow, skill]
keywords: [追従監視, defaultブランチ, resolve-conflict, flow-id-5-2, subscribe_pr_activity, send_later, 自動解消, 停止条件, HANDOFF]
---

# 【設計】【実装】PR作成後のdefaultブランチ追従監視

対象issue: #88 ／ 全体作業計画: `plans/issue88-pr-base-branch-monitoring.md`

種別を併記した理由: 設計（どこに何をどう位置づけるか）と実装（各ファイルへの反映）が
いずれもドキュメント編集であり、分けても合意の単位が変わらず記述が重複するだけのため
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 前提として確認した現状（フェーズ2の代替）

| 対象 | 現状 |
|---|---|
| `issue-mr-flow/SKILL.md` flow-id 5-2 | Draft解除の直前に1回だけ `check-base-conflicts.sh` を実行する。PR作成後〜マージまでの間は扱っていない |
| 同 「defaultブランチとのコンフリクト検知・解消（flow-id 5-2）」節 | 検知 → `AskUserQuestion` → `resolve-conflict` の3分岐のみ |
| `resolve-conflict/SKILL.md` | 類型A（DDR番号）/B（管理外にした生成物）/C（近接行）/D（過去changelog）/E（ロジック競合）。Step 2 で**必ず**ユーザー承認を取る |
| `.claude/docs/ddr/0029-...md` 決定6 | 「解消時はユーザーの承認を必ず取る（`AskUserQuestion`）」 |
| `HANDOFF.md` ヘッダ | `- issue:` `- ブランチ:` `- PR:` `- push回数:` の4行。`update-handoff-progress.sh set-header` はこの4項目のみを書き換え、他の行には触れない |
| `check-base-conflicts.sh` | 引数なしで何度でも実行でき、作業ツリーを変更しない。`--no-fetch` で fetch を省略できる |

`update-handoff-progress.sh` が既存4項目しか触らないため、**ヘッダへ `- 追従監視:` 行を1行足しても
スクリプトの挙動は変わらない**（`set-header` は指定された項目の行だけを書き換える仕様）。

## 設計

### 1. 監視は「flow-idを持たない並行手順」として定義する

- 監視は flow-id 1-3（PR作成）で**開始**し、5-4（マージ）またはPRクローズで**停止**する、
  期間を持つ状態である。1時点で完了するステップではないため、flow-idの新設は行わない。
- 代わりに `issue-mr-flow/SKILL.md` へ独立した節「PR作成後のdefaultブランチ追従（監視）」を置き、
  既存flow-idとの対応表（1-3で開始／各pushの直後・監視イベント受信時に検知／5-2は最終ゲート／
  5-4で停止）で位置づける。
- **flow-id 5-2 は残す。** 監視は実行環境の機能とセッションの寿命に依存するため、必ず通る
  ゲートを1つ残しておかないと「監視が一度も動かないまま Draft解除へ進む」経路ができる。
  5-2の記述は「唯一の検知機会」から「最終ゲート」へ意味づけを変える。

### 2. 実行環境別の手段

| 環境 | 手段 |
|---|---|
| Claude Code on the web | PR作成直後に `subscribe_pr_activity` で購読し、`send_later`（約1時間後）で自己チェックインを予約する。イベント／チェックインのたびに `check-base-conflicts.sh` を実行し、変化が無ければ再予約のみ行って報告しない。PRが merged/closed になったら `unsubscribe_pr_activity` |
| ローカル（git bash） | 購読・予約の仕組みが無いため、人手で `/resolve-conflict` を回す。最低限「各pushの直後」「レビュー対応で作業を再開したとき」「flow-id 5-2」で実行する |

制約として、購読・予約は**セッションに紐づき、リポジトリ側には何も残らない**ことを明記する。
これを補うため、監視の状態を `HANDOFF.md` のヘッダへ1行（`- 追従監視:`）記録し、次セッションの
`resume` で取り直す。`issue-mr-resume` エージェントの現在地サマリにもこの項目を追加する。

### 3. 自動解消してよい範囲（線引き）

**基準: 解消方法が一意に決まる（どちらの意図も失われない）類型に限り、承認を待たずに解消してよい。**
設計判断を含む類型は人間へ回す。issue #88 が挙げた「類型A/C/Dは自動解消、類型Eは人間へ確認」を、
この基準で一般化したもの（類型Bも規則が確定しているため自動解消に含める）。

| 類型 | 監視中の扱い | 根拠 |
|---|---|---|
| A: DDR番号の衝突 | 自動解消 | 「defaultブランチ側を正とし作業ブランチ側を繰り下げる」と規則が確定している |
| B: 管理外にした生成物の "deleted by us" | 自動解消 | 「管理外にした側を採用する」と規則が確定している |
| C: 同じドキュメントの近接行 | 自動解消（両方残す）。ただし散文が両側で書き換わり内容が矛盾する場合はEへ回す | 一覧・表への追記は機械的に統合できる |
| D: spec/DDRの過去changelog | 自動解消（時系列順に両方残す） | 同上 |
| E: 同じロジックの競合 | **人間へ確認**（解消せず止まる） | どちらを採るかで挙動が変わる設計判断 |

自動解消する場合も、`commit` スキル経由でのコミットと `resolve-conflict` Step 5 の検証は省略しない。

### 4. 停止条件

- PRが merged または closed になった（購読を解除する）
- ユーザーが停止を指示した
- セッションが終了した（自動的に止まる。次セッションの `resume` で取り直す）
- 類型Eで止まった場合も**監視自体は続ける**（人間の判断待ちの間にも `main` は進むため）

## 実装手順

1. `.claude/skills/issue-mr-flow/SKILL.md`
   - フロー表の 1-3 行に「PR作成後は追従監視を開始する」旨、5-2 行に「最終ゲート」である旨を追記
   - 「レビュー完了合図の確認」節と「defaultブランチとのコンフリクト検知・解消（flow-id 5-2）」節の
     **間**へ、新節「PR作成後のdefaultブランチ追従（監視）」を差し込む（差し込み位置の直前が
     箇条書きで終わっており、節全体にかかる地の文が無いことを確認済み。
     `.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」）
   - 5-2 節の冒頭へ「本節は最終ゲートであり、継続的な追従は上記の節が正」という1文を追加
2. `.claude/skills/resolve-conflict/SKILL.md`
   - frontmatter の `description` へ監視中の呼び出しを追記
   - 「呼び出しタイミング」へ3つ目の項目（監視中の検知）を追加
   - Step 2 へ「監視モード（非対話・自動解消）」の分岐を追加
   - Step 6・Step 7 へ監視モードでの扱い（コミットメッセージ・報告先）を追記
   - 「詳細ルールへのポインタ」へDDR 0039を追加
3. `.claude/rules/git-workflow.md`: 「PR・マージ」節へサブ節「PR作成後のdefaultブランチ追従」を追加
4. `.claude/agents/issue-mr-resume.md`: 手順7・手順8の報告フォーマットへ「追従監視」を追加

## 検証

- `bash .claude/scripts/src/extract-frontmatter.sh .` が新規・変更ファイルを取り込めること
- 変更したのはmarkdownのみ（`.sh` の変更が無いため `bash -n` の対象は無い）
- 単体テスト `.claude/scripts/test/test_*.sh` が通ること（既存の挙動を壊していないことの確認）
- 差し込み位置の前後3行を目視し、空行が2つ連続していない／次の見出しの直前に空行が1つあること
