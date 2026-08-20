---
title: 【設計反映】GitLab実機検証の結果をspecとDDRへ反映する
type: plan
description: issue #127のフェーズ2〈調査〉・フェーズ3〈作業〉の結果を、.claude/docs/spec/と.claude/docs/ddr/およびGitlab.shのヘッダへ反映する個別反映計画。
tags: [gitlab, spec, ddr, reflection]
keywords: [未決定事項, 提供関数, 差分アンカー, DDR 0059, 検証環境の再現手順, 未検証マーカー, サブグループ]
---

# 個別反映計画（フェーズ4・設計反映）

- 全体作業計画: `plans/zippy-petting-crown.md`
- 結果の正文: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127) / PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)

`plans/` `worklog/` `reports/` の内容のうち、**恒久的に残すべきもの**を
`.claude/docs/spec/` `.claude/docs/ddr/` と `Gitlab.sh` のヘッダへ反映する。
AIアセット（`.claude/rules/` `.claude/skills/`）への反映は
`plans/【AIアセット反映】検証中に気づいたルールの不備を反映する.md` で別に扱う。

## 反映対象

### 1. `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」

**4項目とも「削除」ではなく「範囲を絞る」更新にする。** 今回検証したのはGitLab側だけであり、
項目ごとGitHub側の未検証を含んでいるため（フェーズ2の敵対的レビューで指摘を受けた点）。

| 項目 | 反映内容 |
|---|---|
| （issue #61）`gitlab_set_mr_ready` は実機未検証 | **GitLab側は解消**（`glab` 1.114.0 で `Draft:` 除去・冪等・二重接頭辞も1回で除去）。**GitHub側の `gh pr ready` は未検証のまま残す**ので、項目名をGitHub側に絞って書き換える |
| （issue #68）`search_issues` のCLI経路が実機未検証 | 同上。`glab issue list --search --all` は 1.114.0 で機能しclosedも返る。**`gh issue list --state all` は未検証のまま残す** |
| （issue #13）URL形式が実機（ブラウザ）で未検証 | blob・noteパーマリンク・Compareページの3種はGitLabで目視確認済み。**差分アンカーについては「Compareページでは機能しない」という新事実を書き足す**（下記3も参照）。GitHub側の目視確認状況を確認したうえで、残る範囲を明示する |
| （issue #48・#45で部分解消）GitLab側の動作未検証 | **「プロジェクト構成（サブグループ）」は削除**（3階層namespaceで解決できることを確認済み。`owner` に `grp127/sub127` が入る）。**「バージョン・エディション」は残す**。あわせて「issue #127 で残る13関数も `Provider.sh` 経由で確認した」旨を追記する |

### 2. 「提供関数」表（同ファイル）

| 行 | 反映内容 |
|---|---|
| `get_diff_anchor_url` | 説明の「Compareページ内の…」を「差分ページ内の…」へ。引数名を `<baseUrl>` へ。**土台はプロバイダで異なる**旨を明記 |
| `get_diff_anchor_algo` | GitLab欄の **`sha1`（【未検証】）から【未検証】を外す**（実機確認済み）。ハッシュ入力が**percent-encode前の生パス**である旨を追記 |
| **新規行3つ** | `get_diff_anchor_base_url` / `get_mr_url` / `get_note_url` を追加する |

あわせて、**hookのレビュー依頼メッセージを説明している箇所**（「差分アンカーリンク（Compareページ内の
該当ファイル位置）」と書かれている行）も土台の説明を実態へ合わせる。

### 3. 新規DDR 0059（差分アンカーの土台）

**次の空き番号は 0059**（現在の最大は `0058-フェーズ5は片付けをcommit直前へ移した順序に並べ替える.md`）。

内容:

- **決めたこと**: 差分アンカーの土台をプロバイダごとに分け、GitLabは MR差分ページを使う。
  2回目以降のpushは `?start_sha=<prev_sha>` で範囲を絞り、初回pushは `<mrUrl>/diffs`。
- **原則**: 土台が覆う範囲を、ファイル一覧の供給元 `diff_range` と一致させる。
- **却下案**: 案A（MR全体の差分。前のpushで追加し今回削除したファイル＝改名も同型で
  アンカーが着地先を失う。実測で確認）、案C（GitLabではアンカーを出さない）。
- **残した妥協**: `prev_sha` がMRバージョンのheadでない場合の縮退は案Aと同じ形になり、
  原則を満たせない。根治には issue #23 のhook誤検知を直す必要がある。
- **DDR 0037 との関係**: 同DDRは「pushのたびに走る本hookから外部CLIの起動とAPI往復が1回ずつ
  無くなっている」ことを成果として記録しているが、本変更は**GitLabかつ2回目以降のpushで
  API往復を1回足し戻している**。その判断（無言で0ファイルの差分ページを出すより良い）を残す。
- **「同じハッシュでもページによって効く／効かないが変わる」という、GitHub側の前例からは
  予測できなかった事実**を記録する。これが本issueで最も価値のある発見である。

### 4. DDR 0060（要否をこの計画で判断する）

「単体テストが緑でも呼び出し経路は保証されない」「並行ブランチのsemantic conflictをgitは
報告しない」という教訓を独立したDDRにするか。

**この計画では「作らない」と判断する。** これらは意思決定（何を採用し何を却下したか）ではなく
教訓であり、DDRの体裁に合わない。**再発防止の実装そのもの**（`test_vcs_provider.sh` の静的検出と
共有関数の表明）が残るうえ、テストのコメントに理由が書かれている。教訓として残す価値がある部分は
AIアセット反映側（`.claude/rules/shell-script-style.md`）で扱う。

### 5. `.claude/docs/spec/shell-scripts.md`

| 箇所 | 反映内容 |
|---|---|
| 29行目（移植表の `Gitlab.sh` 行） | 「（未検証。GitLab実remoteが無いため）」を実態へ。issue #48・#45・#127 で検証済みであることと、残る未検証範囲（バージョン・エディション）を書く |
| 165〜166行目「GitLab版の実機動作未検証」 | 同上。**項目ごと削除するのではなく、残る範囲へ絞る** |

### 6. `.claude/scripts/src/vcs/Gitlab.sh` の検証状況

| 箇所 | 反映内容 |
|---|---|
| ファイルヘッダ | **issue #45 で解消済みなのに「未修正」と書いている記述を訂正**。検証済み関数の数を実態へ（**#48当時13 − 1 + 今回13 = 25**。引かれる1件が `gitlab_get_repo_url`）。「プロジェクト構成（サブグループ）」の未検証も削除。残るのはバージョン・エディションのみ |
| **関数個別の【未検証】マーカー** | `gitlab_diff_anchor_algo` と `gitlab_add_issue_comment` に残っている【未検証】を外す（フェーズ3の敵対的レビューで指摘。**ヘッダだけ直すと、同じファイル内で矛盾した記述が並ぶ**） |

### 7. 検証環境の再現手順の恒久化（受け入れ条件8）

`reports/…GitLab実機検証結果.md` の「受け入れ条件8: 検証環境の再現手順」節は、flow-id 5-3 で
`reports/` ごと削除されるため、**このままでは受け入れ条件8が満たされない**。

- 移設先案: **新規ファイル `.claude/docs/spec/gitlab-verification-environment.md`**。
  `Gitlab.sh` の検証を再現するための環境（Docker・`glab` 認証・接続手段・既知の落とし穴）を扱う。
- **新規specファイルの作成には人間の承認が必須**（`.claude/rules/docs-workflow.md`）。
  この計画のレビュー（flow-id 4-3〜4-4）で承認を得る。
- 既存ファイルへ節として入れる案（`shell-scripts.md` へ）も考えられるが、同ファイルは
  「bashスクリプト全般の設計方針」を扱っており、GitLab検証環境の構築手順は主題が異なる。

## この計画で決めないこと

- **AIアセット（`.claude/rules/` `.claude/skills/`）への反映**。別計画で扱う。
- **ブラウザ目視確認の結果**。未完了のため、反映時点で結果が出ていなければ
  「目視確認は依頼中」という状態のまま spec へ書く（**確認できていないことを確認済みとして
  書かない**）。結果が出たら該当箇所を更新する。
- issue #23（hookのpush誤検知）の修正。DDR 0059 に「根治には必要」と書くに留める。

## 検証（この計画自体の完了条件）

1. `bash .claude/scripts/src/extract-frontmatter.sh .` が通り、新規ファイルが
   `index.jsonl` に載る（新規specを作った場合）。
2. **DDR番号の重複が無い**: `ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d` が空。
3. `.claude/docs/README.md` のDDR一覧へ 0059 を追記済み。
4. **「未検証」「未修正」という語の残存を、件数つきで確認する**（0件を期待するのではなく、
   残っているものが**意図して残した範囲**であることを1件ずつ確認する）。

   ```bash
   grep -c '未検証' .claude/scripts/src/vcs/Gitlab.sh
   grep -n '未検証\|未修正' .claude/scripts/src/vcs/Gitlab.sh
   ```

5. 単体テスト12本が `failures=0`（ドキュメント変更だけでも、`index.jsonl` 再生成の副作用が
   無いことを確認する）。
