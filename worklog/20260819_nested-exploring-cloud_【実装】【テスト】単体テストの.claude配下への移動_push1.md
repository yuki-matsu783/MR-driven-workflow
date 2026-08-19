---
title: worklog 単体テストの.claude/scripts/test配下への移動
type: log
description: issue #63でワークフロー機構の単体テスト4本をtests/から.claude/scripts/test/へ移動した際の作業ログ
tags: [worklog, test, directory-structure]
keywords: [tests, .claude/scripts/test, git mv, repo_root, sync-assets, パス参照, DDR 0029, 回帰確認]
---

# worklog: 【実装】【テスト】【設計反映】単体テストの `.claude/scripts/test/` への移動

対象: issue #63（2026-08-19）。
全体作業計画: `plans/nested-exploring-cloud.md`
個別作業計画: `plans/【実装】【テスト】単体テストの.claude配下への移動.md`,
`plans/【設計反映】テスト配置変更をspec_DDRへ反映.md`
push回数: 1

## 試したこと

- 移動前に4本を実行してベースラインを控えた（17 / 15 / 33 / 36 = 101件、いずれも `failures=0`）。
  アサーションを一切変えない移動のため、**内訳の一致そのものを回帰判定にする**方針を採った。
- `git mv` で4本を移動。`git status --short` が4本とも `R`（rename）と表示することを確認し、
  履歴が保持されていることを確かめた。
- `repo_root` 算出は4本とも同じ定型（`repo_root="$(cd "$script_dir/.." && pwd)"`）だったため、
  `sed` の一括置換で `../../..` へ。冒頭コメントの `実行: bash tests/...` も同時に更新。
- `.claude/rules/docs-workflow.md` の「過去changelogを書き換えない」規定に従えているかを、
  `git diff -U0 | grep '^-'` で削除行だけを抽出して確認した。

## うまくいったこと

- 移動後も `passed` の内訳が 17 / 15 / 33 / 36 で完全一致。パス解決だけの変更で済んだことが確認できた。
- `sync-assets.sh` は `.claude/` 配下をそのままコピーする作りだったため、**配布スクリプト側の変更は
  一切不要**だった。issueの目的（導入先へテストを同梱しつつ導入先本体の `tests/` と衝突させない）が、
  移動だけで両方満たされた。
- 削除行の抽出結果は12行すべてが「現在の状態を説明する記述」で、DDR本文・`## 影響範囲` の
  過去エントリは1行も消えていなかった。
- 新規DDR 0029 のfrontmatterが `extract-frontmatter.sh` で正しく索引化されることを確認
  （`files=53 built=53`）。

## ダメだったこと

- `shellcheck source=../.claude/...` ディレクティブの更新を初回の一括置換で入れ忘れ、後から
  追加で置換した。テスト実行では検出できない（shellcheckを回していない）ため、`grep` で
  相対パスを含む行を洗い出す手順を先に踏むべきだった。
- `test_update_handoff_progress.sh` 冒頭の「`tests/test_vcs_provider.sh` を雛形にした」は
  バッククォートで囲まれておらず、バッククォート前提の置換パターンから漏れた。同じ文字列でも
  装飾の有無で置換が空振りするため、置換後の `grep` 確認は必須。

## 判断したこと

- `tests/test_external_command_server.sh` を指す3箇所（`shell-script-style.md` L188・L275、
  `shell-scripts.md` L33）は**更新しない**と判断した。このファイルはこのリポジトリに存在せず
  （移植元から持ち込まれた記述）、移動していないファイルのパスを新パスへ書き換えると事実と
  異なる記録になるため。issueの受け入れ条件「「テスト」節が新パスを指している」は、実在する
  `test_vcs_provider.sh` を指す行（L270相当）の更新で満たしている。
- `.claude/docs/spec/shell-scripts.md` の「対象スクリプト一覧」は `## 仕様` 節にあるが、
  内容としては bash化当時の旧→新対応表である。実在する `test_vcs_provider.sh` の行のみ、
  「新規作成当時は `tests/...`。issue #63 で移動」と**当時のパスを残したまま**現在地を併記する形にした。
  パスだけ差し替えると「bash化時点で `.claude/scripts/test/` にあった」という誤った記録になるため。

## 次の一歩

- 特になし（実装・テスト・設計反映まで完了）。
- 残課題として、PR #56（OPEN）が `tests/test_vcs_provider.sh` を変更しているため、
  後からマージする側で rename/modify conflict の解決が必要。
