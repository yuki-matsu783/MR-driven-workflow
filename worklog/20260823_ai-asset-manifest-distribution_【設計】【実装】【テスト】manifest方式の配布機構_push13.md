---
title: worklog 20260823 manifest方式の配布機構 push13
type: log
description: 敵対的レビュー3回目（フェーズ3・上限）の指摘16件を3周目のレビュー往復で反映した際の試行錯誤ログ
tags: [worklog, adversarial-review, distribution, performance]
keywords: [敵対的レビュー, requiredLine, 起動回数, sha256, git status, 連想配列, HTMLビュー, 配布先, upstream, GIT_INDEX_FILE]
---

# worklog: 【設計】【実装】【テスト】manifest方式の配布機構

対象: 敵対的レビュー3回目（フェーズ3・上限3回目）の指摘16件の反映（2026-08-23）。
全体作業計画: `plans/ai-asset-manifest-distribution.md`
個別作業計画: `plans/【設計】【実装】【テスト】manifest方式の配布機構.md`
push回数: 13

結果の正文は `reports/20260822_ai-asset-manifest-distribution_manifest方式の実装結果.md`
「敵対的レビュー3回目の反映（flow-id 3-9 の3周目）」節。ここには**そこへ書かなかった
試行錯誤**だけを残す。

## 試したこと

- **指摘の裏取り**: 16件のうち、挙動が変わると主張するもの（配布先テストの失敗・起動回数・
  コマンドライン長・`AGENTS.md` の移行漏れ・`.gitignore` 最終行）は、直す前に**実際に再現**
  させてから着手した。とくに配布先テストは、実際に配布したディレクトリで17本を流して
  `test_check_dist_coverage.sh` だけが `passed=11 failures=15` になることを確認している。
- **起動回数の計数**: `jq` `sha256sum` `cp` `mkdir` `git` `tr` `grep` `xargs` を数えるスタブを
  PATHの先頭へ置き、配布1回ぶんの起動数を前後で実測した（1208 → 176）。
  「速くなったはず」で終わらせないため、**同じスタブで前後を測る**ことに揃えた。
- **`git status` の pathspec 回避**: レビューは `--pathspec-from-file` を使えと提案していたが、
  実機（git 2.43）で `error: unknown option` になった。`git add` / `git commit` にはあるが
  `git status` には無い。**pathspecを渡すのをやめる**方向（リポジトリ全体を1回取り、bash側の
  連想配列で突き合わせる）で解いた。
- **`requiredLine` の検証**: 新しい表明が本当に検出するかを確かめるため、`dist-layers.json` から
  `requiredLine` を一時的に抜いて `test_install_to_project.sh` を流し、`failures=3` になることを
  確認してから戻した。

## うまくいったこと

- **`GIT_INDEX_FILE` によるindexの隔離**。`test_check_dist_coverage.sh` は検査1の分母を作るために
  `git add -N` / `git rm --cached` で**実行先リポジトリのindexを書き換えて**いた。indexの写しを
  作って `GIT_INDEX_FILE` で渡すと `git ls-files` はその写しを見るので、実リポジトリは
  1バイトも変わらない。「実リポジトリのindexにプローブが入っていない」ことも表明に足した。
- **`upstream` の印でスキップ判定する**。それまでの判定は「対象ファイルが存在するか」だったが、
  `.claude/scripts/test/` は core として丸ごと配られるので配布先でも存在してしまう。
  `jq -e '.upstream == true'` にすると、**配布時に `del(.upstream)` で落としている**ことが
  そのままスキップ条件になる（新しい仕組みを足さずに済んだ）。
- **`sha256_lf_batch` のCR判定**。LF正規化のために全ファイルを `tr` へ通すと1ファイル1起動に
  戻ってしまう。CRを含むファイルだけを `grep -lU` 1回で洗い出し、**残りは `sha256sum` へ
  まとめて渡す**形にしたところ、564起動が15になった。CRを含むファイルは実際には0件なので、
  この経路はほぼ常に空振りする。

## ダメだったこと

- **`${!group[@]+"${!group[@]}"}` が動かなかった。** インデックス配列の空配列ガード
  `${a[@]+"${a[@]}"}` と同じつもりで連想配列のキーへ書いたところ、
  `bash: 2 1: invalid variable name` で落ちた。bashが `!group[@]+…` を**間接展開**として解釈し、
  キーではなく**値**を変数名として扱おうとするためである（最小再現で確認した）。
  件数を先に見る形（`if [ "${#group[@]}" -gt 0 ]; then … fi`）へ直した。
  - 表面化の仕方が悪い。エラーメッセージに出る `2 1` は連想配列の**値**であり、変数名にも
    キーにも見えないので、原因の見当がつきにくい。
- **レポートの「全17ファイル passed=1102」が誤りだった。** 個別に流したときの数を足し込んで
  書いていたもので、実際に全ファイルを流すと `passed=1098` だった。**書く前に必ず通しで
  流す**こと（コミット前に気づいて直した）。
- **python の一括置換スクリプトが `assert s.count(old) == 1` で止まり、ファイルが書かれずに
  終わった。** `SCAN_MERGE` の該当箇所が2つあったため。assertで止まったこと自体は正しい挙動だが、
  **「実行した＝直った」と思い込みかけた**（直後に `grep` で確認して気づいた）。置換系の
  スクリプトは、実行後に必ず対象を読み直す。
- **HTMLの見出し照合が空振りしかけた。** `grep -oE '<h2>[^<]*</h2>'` は `<code>` を含む見出しに
  一致しないため、実際には対応しているのに「HTML側に無い」と見えた。タグを除去してから
  比較する形へ直した。**「差分が出た」ではなく「照合方法が対象に合っていない」ことを先に疑う。**

## 次の一歩

- flow-id 3-9: PR #154 へ投稿した10スレッドへ返信する（報告のみの6件も併せて扱う）。
- flow-id 3-10: `describe` でPR descriptionを更新する。
- フェーズ4へ持ち越し: `.claude/docs/spec/distribution-assets.md` 102行目の
  `ensure_gitattributes_rules`（削除済み）の記述を新方式へ書き換える。
  **DDR `i0033-03` の同じ記述は本文なので書き換えない。**

---
