---
title: 【設計反映】GitLab実機検証の結果をspecとDDRへ反映する
type: plan
description: issue #127のフェーズ2〈調査〉・フェーズ3〈作業〉の結果を、.claude/docs/spec/と.claude/docs/ddr/およびGitlab.shのヘッダへ反映する個別反映計画。
tags: [gitlab, spec, ddr, reflection]
keywords: [未決定事項, 提供関数, 差分アンカー, DDR 0059, 検証環境の再現手順, 未検証マーカー, 影響範囲, サブグループ]
---

# 個別反映計画（フェーズ4・設計反映）

- 全体作業計画: `plans/zippy-petting-crown.md`
- 結果の正文: `reports/20260820_zippy-petting-crown_GitLab実機検証結果.md`
- issue: [#127](https://github.com/yuki-matsu783/MR-driven-workflow/issues/127) / PR: [#128](https://github.com/yuki-matsu783/MR-driven-workflow/pull/128)

`plans/` `worklog/` `reports/` の内容のうち、**恒久的に残すべきもの**を
`.claude/docs/spec/` `.claude/docs/ddr/` と `Gitlab.sh` のヘッダへ反映する。
AIアセット（`.claude/rules/` `.claude/skills/`）への反映は
`plans/【AIアセット反映】検証中に気づいたルールの不備を反映する.md` で別に扱う。

**「GitLab remoteが無いため未検証」という前提で書かれた記述が、複数のファイル・複数の節に
散らばっている。** 一部だけを直すと、残った古い記述のほうが新しく見える（更新した節ほど
「範囲を絞った」控えめな書き方になるため）。**下の一覧が網羅であることを、検証節の grep で
確かめてから終える。**

## 反映対象

### 1. `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」

**「削除」ではなく「範囲を絞る」更新を基本にする。** 今回検証したのはGitLab側だけであり、
項目ごとGitHub側の未検証を含んでいるものがあるため（フェーズ2の敵対的レビューでの指摘）。

| 項目 | 反映内容 |
|---|---|
| （issue #61）`gitlab_set_mr_ready` は実機未検証 | **GitLab側は解消**（`glab` 1.114.0 で `Draft:` 除去・冪等・二重接頭辞も1回で除去）。**GitHub側の `gh pr ready` は未検証のまま残す**ので、項目名をGitHub側に絞って書き換える |
| （issue #68）`search_issues` のCLI経路が実機未検証 | 同上。`glab issue list --search --all` は 1.114.0 で機能しclosedも返る。**`gh issue list --state all` は未検証のまま残す** |
| （issue #42）**差分アンカーの「ブラウザで実際にスクロールするか」は未検証**（2981行） | **GitLab側は結論が出た**（Compareページでは飛ばない／MR差分ページなら初回から飛ぶ）。**修正後の目視確認（4本）が未完了**なので、その状態を明記して残す。GitHub側の目視状況を確認し、残る範囲を明示する |
| （issue #42）**GitLab側の重点ファイルリンク・コメントパーマリンクは【未検証】**（2989行） | **削除する。** `get_blob_url`（HTTP 200・encode必須）・差分アンカー（sha1が `id=` と一致）・noteパーマリンク（GitLab自身の `noteable_note_url` と一致）をすべて実機確認済みで、**前提（「本リポジトリにGitLab remoteが無い」）自体が成立しない** |
| （issue #86）`add_issue_comment` のCLI経路が実機未検証（2995行） | **GitLab側は解消**（検証対象13関数の#4として `Provider.sh` 経由で実行し、issue側へnoteが1件付いた）。GitHub側の状況を確認し、残るなら範囲を絞る |
| （issue #48・#45で部分解消）GitLab側の動作未検証 | **「プロジェクト構成（サブグループ）」は削除**（3階層namespaceで解決でき、`owner` に `grp127/sub127` が入る）。**「バージョン・エディション」は残す**。あわせて issue #127 で残る13関数を確認した旨を追記する（下記の粒度に注意） |

**13関数の確認の粒度を落とさない。** 「13関数も `Provider.sh` 経由で確認した」とだけ書くと、
**`Provider.sh` にディスパッチャが無い関数がある**という事実が失われる。次のように書く。

- 公開ディスパッチャを持つものは**直接**呼んで確認した。
- `get_mr_url` / `get_note_url` は**本issueでディスパッチャを追加**して直接確認へ格上げした。
- `add_mr_thread` / `build_discussion_body` / `summary_post_kind` は**ディスパッチャを持たず**、
  `add_mr_inline_comments` 経由の**間接確認**である（`add_mr_thread` は意図的に追加していない。
  GitHubに対応物が無いため）。

### 2. 「提供関数」表と、仕様本文の差分アンカーの説明（同ファイル）

| 箇所 | 反映内容 |
|---|---|
| `get_diff_anchor_url` 行 | 説明の「Compareページ内の…」を「差分ページ内の…」へ。引数名を `<baseUrl>` へ。**土台はプロバイダで異なる**旨を明記 |
| `get_diff_anchor_algo` 行 | GitLab欄の `sha1`（**【未検証】**）から【未検証】を外す。ハッシュ入力が**percent-encode前の生パス**である旨を追記 |
| **`add_issue_comment` 行（102行）** | GitLab欄の「`glab api`（issues notes追加。**【未検証】**）」から【未検証】を外す。**ここを直さないと「実装ファイルは検証済み・仕様書は未検証」という食い違いが確定する**（§6と対になっている） |
| **新規行3つ** | `get_diff_anchor_base_url` / `get_mr_url` / `get_note_url` を追加する |
| 1204行（レビュー依頼メッセージの説明） | 「差分アンカーリンク（Compareページ内の該当ファイル位置）」の土台の説明を実態へ |
| **1224〜1228行（ハッシュ算出方法の説明）** | GitHubのCompareページ前提のままなので、土台がプロバイダで分かれた事実を追記。**1228行の「GitLab側（パスのsha1）は本リポジトリにGitLab remoteが無いため【未検証】」を実機確認済みの記述へ差し替える** |

**2185行（issue #42 の「影響範囲」エントリ）には1228行とほぼ同じ文言があるが、こちらは
point-in-timeの記録なので書き換えない**（`.claude/rules/docs-workflow.md`「ファイル移動に伴う
パス参照の一括置換は…過去changelogを対象に含めない」と同じ理由）。**一括置換を使わず、
現在の仕様を説明している節だけを個別に直す。**

### 3. 「影響範囲」への `### issue #127` エントリ追加（同ファイル）

`## 影響範囲` 配下は `### issue #NN` の形で変更履歴を積む運用（直近は `### issue #115` /
`### issue #112`）。issue #127 はこのspecが記述対象にしている挙動を実際に変えているため、
**エントリを追加しないと、提供関数表に3行増えた理由・土台が変わった経緯を、この節から辿れない**。

書く内容: `Provider.sh` への3ディスパッチャ追加、`get_diff_anchor_url` の引数の意味の変更
（compareURL → 土台URL）、`post-push-compact-prompt.sh` の土台URL決定の委譲、`Gitlab.sh` の
未定義呼び出しの修正、DDR 0059 へのリンク。

### 4. `.claude/docs/spec/adversarial-review.md`（388行）

> **非インラインのスレッド投稿は未検証。** このリポジトリにGitLab remoteが無く、
> `gitlab_add_mr_thread` を実機で叩けていない（`position` を持たない `discussions` へのPOSTと、
> それがMR上で解決可能なスレッドになることの確認）。

**この項目が求めていた確認は今回済んでいる。** run2（有効2件＋不正1件）で
`{"posted":2,"summarized":1}` を得て、サマリが `individual_note=false` / `resolvable=true` の
スレッドになったことまで確認した。**削除するか、残る範囲へ絞る。**

### 5. 新規DDR 0059（差分アンカーの土台）

**次の空き番号は 0059**（現在の最大は `0058-フェーズ5は片付けをcommit直前へ移した順序に並べ替える.md`）。

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

### 6. DDR 0060（要否をこの計画で判断する）

「単体テストが緑でも呼び出し経路は保証されない」「並行ブランチのsemantic conflictをgitは
報告しない」という教訓を独立したDDRにするか。

**この計画では「作らない」と判断する。** これらは意思決定（何を採用し何を却下したか）ではなく
教訓であり、DDRの体裁に合わない。**再発防止の実装そのもの**（`test_vcs_provider.sh` の静的検出と
共有関数の表明）が残るうえ、テストのコメントに理由が書かれている。
**教訓としての記録はAIアセット反映側が受け取る**（同計画 §1 に該当項目があることを、
本計画のレビュー時に突き合わせる。**片方が「あちらで扱う」と書いて他方が受け取らない状態を作らない**）。

### 7. `.claude/docs/spec/shell-scripts.md`

| 箇所 | 反映内容 |
|---|---|
| 29行目（移植表の `Gitlab.sh` 行） | 「（未検証。GitLab実remoteが無いため）」を実態へ。issue #48・#45・#127 で検証済みであることと、残る未検証範囲（バージョン・エディション）を書く |
| 165〜166行目「GitLab版の実機動作未検証」 | 同上。**項目ごと削除するのではなく、残る範囲へ絞る** |

### 8. `.claude/scripts/src/vcs/Gitlab.sh` の検証状況

| 箇所 | 反映内容 |
|---|---|
| ファイルヘッダ | **issue #45 で解消済みなのに「未修正」と書いている記述を訂正**。「プロジェクト構成（サブグループ）」の未検証も削除。残るのはバージョン・エディションのみ |
| **関数の数** | **`13 − 1 + 13 + 2 = 27`**（引かれる1件が `gitlab_get_repo_url`、足す2件が本issueで追加した `gitlab_get_diff_anchor_base_url` / `gitlab_mr_has_version_head`）。実測でも `grep -c '^gitlab_[a-z0-9_]*()'` が **27** を返す。**「25」と書くと、定義が27ある以上、残る2つが未検証なのか数え漏れなのか読み手が判断できない**（#48当時のヘッダが「全13関数」のまま関数が増えて実態と合わなくなった、今まさに訂正しようとしている失敗の再演になる）。数を書かず「本ファイルの全関数」と表現して陳腐化を避ける案も検討する |
| **関数個別の【未検証】マーカー** | `gitlab_diff_anchor_algo` と `gitlab_add_issue_comment` に残っている【未検証】を外す（**ヘッダだけ直すと、同じファイル内で矛盾した記述が並ぶ**） |

### 9. 検証環境の再現手順の恒久化（受け入れ条件8）

`reports/…GitLab実機検証結果.md` の「受け入れ条件8: 検証環境の再現手順」節は、flow-id 5-3 で
`reports/` ごと削除されるため、**このままでは受け入れ条件8が満たされない**。

- 移設先案: **新規ファイル `.claude/docs/spec/gitlab-verification-environment.md`**。
  `Gitlab.sh` の検証を再現するための環境（Docker・`glab` 認証・接続手段・既知の落とし穴）を扱う。
- **新規specファイルの作成には人間の承認が必須**（`.claude/rules/docs-workflow.md`）。
  この計画のレビュー（flow-id 4-3〜4-4）で承認を得る。
- 作る場合は**frontmatter（`type: spec` と title / description / tags / keywords）を付け、
  `.claude/docs/README.md` のspec一覧へも追記する**（載せないと目次から辿れない）。
- 既存ファイルへ節として入れる案（`shell-scripts.md` へ）も考えられるが、同ファイルは
  「bashスクリプト全般の設計方針」を扱っており、GitLab検証環境の構築手順は主題が異なる。

### 10. 未完了事項の受け皿

`reports/` は flow-id 5-3 で削除されるため、**「未完了（範囲内）」の2件に恒久的な行き先が
無いと痕跡ごと消える**（reportは「範囲外と混同するな」と明記している）。

| 未完了事項 | 受け皿 |
|---|---|
| 修正後の差分アンカーのブラウザ目視確認（4本） | §1の（issue #42）2981行の項目へ「修正後の目視確認は未完了」として書く。**回答が得られていれば結果を書き、得られていなければ未完了のまま書く**（確認できていないことを確認済みとして書かない） |
| **折りたたまれた差分に対するアンカーの挙動**（402行のファイルでも `collapsed` が立たず、畳まれる条件が未特定） | 「未決定事項・懸念点」へ**1項目として追加する**。後続issueの起票は行わない（AIから着手を持ちかけない方針と揃える。必要なら人間が起票する） |

## この計画で決めないこと

- **AIアセット（`.claude/rules/` `.claude/skills/`）への反映**。別計画で扱う。
- issue #23（hookのpush誤検知）の修正。DDR 0059 に「根治には必要」と書くに留める。
- gitlab.com・他バージョン・EEの検証（issue #127 の期待する動作7で範囲外と決めたもの）。

## 検証（この計画自体の完了条件）

1. frontmatterインデックスが通り、新規ファイルが載る（新規specを作った場合）。

   ```bash
   bash .claude/scripts/src/extract-frontmatter.sh .
   ```

2. **DDR番号の重複が無い**（何も出力されなければ重複なし）。

   ```bash
   ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d
   ```

3. `.claude/docs/README.md` の**DDR一覧へ0059**を、**spec一覧へ新規spec**を追記済み。

   ```bash
   grep -n '0059' .claude/docs/README.md
   grep -n 'gitlab-verification-environment' .claude/docs/README.md
   ```

4. **「未検証」「未修正」「GitLab remote」の残存を、反映先全体に対して件数つきで確認する。**
   0件を期待するのではなく、**残っている1件ずつについて「意図して残した範囲か／
   changelogなので触らないものか」を書き残す**（`Gitlab.sh` だけを見る形だと、
   取り残しが最も起きやすいspec側を検証が見ないことになる）。

   ```bash
   grep -rn '未検証\|未修正\|GitLab remote' \
     .claude/scripts/src/vcs/Gitlab.sh \
     .claude/docs/spec/issue-mr-workflow.md \
     .claude/docs/spec/shell-scripts.md \
     .claude/docs/spec/adversarial-review.md
   ```

5. `Gitlab.sh` のヘッダに書いた関数の数が実測と一致する。

   ```bash
   grep -c '^gitlab_[a-z0-9_]*()' .claude/scripts/src/vcs/Gitlab.sh   # 27
   ```

6. 単体テストが全数 `failures=0`（ドキュメント変更だけでも、`index.jsonl` 再生成の副作用が
   無いことを確認する）。

   ```bash
   for f in .claude/scripts/test/test_*.sh; do printf '%-46s ' "${f##*/}"; bash "$f" | tail -1; done
   ```
