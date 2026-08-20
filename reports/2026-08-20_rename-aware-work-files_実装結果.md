---
title: 実装結果 get_branch_work_filesの改名対応（issue #115）
type: report
description: get_branch_work_filesを--porcelain -zへ移し、改名を新パス1件として返すようにした実装結果と実機確認の記録。
tags: [report, provider, workflow, test]
keywords: [get_branch_work_files, porcelain_z_to_paths, -z, 改名, rename, NUL, quotepath, 受け入れ条件, 実機確認]
---

# 実装結果: `get_branch_work_files` の改名対応（issue #115）

全体作業計画: `plans/rename-aware-work-files.md`
個別作業計画: `plans/【実装】【テスト】改名パスの一覧化.md` /
`plans/【設計反映】改名パスの一覧化.md` / `plans/【AIアセット反映】改名パスの一覧化.md`
対象issue: [#115](https://github.com/yuki-matsu783/MR-driven-workflow/issues/115)（2026-08-20）

## 結論

`get_branch_work_files` の未コミット分の取得を `git status --porcelain`（行単位）から
`git status --porcelain -z`（NUL区切り）へ移し、その分解を純粋関数 `porcelain_z_to_paths` へ
切り出した。**出力は常に「1行＝1つの実在するパス」**になり、改名されたファイルは新パスのみが
返る。改名が無い場合の出力は従来と同一である。

## 変更点

| ファイル | 変更 |
|---|---|
| `.claude/scripts/src/vcs/Provider.sh` | `porcelain_z_to_paths` を新設。`get_branch_work_files` の `working=` を `--porcelain -z \| porcelain_z_to_paths` へ変更。`core.quotepath` のヘッダコメントを現状に合わせて更新 |
| `.claude/scripts/test/test_vcs_provider.sh` | `porcelain_z_to_paths` の単体テストを9ケース追加（131 → 140ケース） |
| `.claude/docs/spec/issue-mr-workflow.md` | 「提供関数」表へ `porcelain_z_to_paths` を追加、「改名されたファイルの扱い（issue #115）」節を新設、「日本語ファイル名を扱う際の注意」を更新、変更履歴へエントリ追加 |
| `.claude/rules/shell-script-style.md` | 「コマンド置換とNULバイト」節へ「`git status --porcelain` からパスを取り出すときは `-z` を付ける」を追加 |

実装の中核は次の1行と、それを支える純粋関数である。

```bash
working="$(git -c core.quotepath=false status --porcelain -z -- "$plans_dir" "$worklog_dir" "$reports_dir" | porcelain_z_to_paths)"
```

`porcelain_z_to_paths` がNULを吸収して改行区切りへ変換するため、**呼び出し側は従来どおり
`$(...)` で受け取れる**（`.claude/rules/shell-script-style.md`「コマンド置換とNULバイト」の制約が
`get_branch_work_files` 側へ波及しない）。結果として関数後半の `sed '/^$/d' | sort -u` は
一切変更していない。

## 根拠（実機で確かめたこと）

### 1. `-z` の改名エントリは「新パスが先」

一時リポジトリ（`git init` した検証用。日本語名・ASCII名の両方を `git mv`）で確認した。

```
$ git -c core.quotepath=false status --porcelain -- plans
RM plans/ascii-old.md -> plans/ascii-new.md
R  plans/【調査】旧.md -> plans/【調査】新.md
?? plans/untracked.md

$ git -c core.quotepath=false status --porcelain -z -- plans | od -c
0000000   R   M       p   l   a   n   s   /   a   s   c   i   i   -   n
0000020   e   w   .   m   d  \0   p   l   a   n   s   /   a   s   c   i
0000040   i   -   o   l   d   .   m   d  \0   R           p   l   a   n
0000060   s   / 343 200 220 350 252 277 346 237 273 343 200 221 346 226
0000100 260   .   m   d  \0   p   l   a   n   s   / 343 200 220 350 252
...
```

- 改名エントリは `XY <新パス>\0<旧パス>\0` の2フィールドで、**行単位形式（`<旧> -> <新>`）とは
  順序が逆**。
- `core.quotepath=false` の下では非ASCIIが生のUTF-8バイト（`343 200 220` = `【`）で出る。

### 2. 行単位形式は原理的に曖昧（自作パーサでは直せない）

パス自体が ` -> ` を含む改名を実機で作った（`plans/arrow -> old.md` → `plans/arrow -> new.md`）。

```
$ git -c core.quotepath=false status --porcelain -- plans | sed -E 's/^...//'
"plans/arrow -> old.md" -> "plans/arrow -> new.md"     ← ` -> ` が3回現れ、さらにクォートされる
plans/ascii-new.md
plans/untracked.md

$ git -c core.quotepath=false status --porcelain -z -- plans | porcelain_z_to_paths
plans/arrow -> new.md
plans/ascii-new.md
plans/untracked.md
```

「最後の ` -> ` で分割する」「最初の ` -> ` で分割する」のどちらでも壊れる。加えて、**空白を含む
パスはダブルクォートで囲まれる**ため、行単位形式にはアンクォート処理も必要になる。
`-z` へ移す判断の決め手はここにある（この点はissue本文に書かれていなかった追加の発見）。

### 3. 本リポジトリでの実機確認（受け入れ条件1・2・3・5）

本ブランチ上で、コミット済みの `plans/REVIEW-POINTS.md` を一時的に日本語名へ `git mv` して
確認した（確認後に元へ戻してある）。

```
=== 旧実装の見え方（参考） ===
plans/REVIEW-POINTS.md -> plans/【一時】改名検証.md      ← 存在しないパス
plans/rename-aware-work-files.md
...

=== 新実装 get_branch_work_files ===
plans/rename-aware-work-files.md
plans/【AIアセット反映】改名パスの一覧化.md
plans/【一時】改名検証.md                                 ← 新パスのみ
plans/【実装】【テスト】改名パスの一覧化.md
plans/【設計反映】改名パスの一覧化.md
worklog/2026-08-20_rename-aware-work-files_【実装】【テスト】改名パスの一覧化_push1.md

=== 各行が実在するか（[ -e "$f" ]） ===
OK   plans/rename-aware-work-files.md
OK   plans/【AIアセット反映】改名パスの一覧化.md
OK   plans/【一時】改名検証.md
OK   plans/【実装】【テスト】改名パスの一覧化.md
OK   plans/【設計反映】改名パスの一覧化.md
OK   worklog/2026-08-20_rename-aware-work-files_【実装】【テスト】改名パスの一覧化_push1.md
```

- 出力に `" -> "` を含む行は無く、**全行が `[ -e ]` で実在**した。
- 日本語ファイル名が8進エスケープされずそのまま返っている（`-c core.quotepath=false` の維持）。
- `git mv` を元へ戻した状態で再実行すると、改名の行が消えるだけで**他の行は完全に同一**だった
  （改名が無い場合は従来と変わらない＝受け入れ条件5）。

### 4. 単体テスト（受け入れ条件4）

```
$ bash .claude/scripts/test/test_vcs_provider.sh
passed=140 failures=0
```

追加した9ケースは、`git status --porcelain -z` の出力を模したフィクスチャ（NULを含むため
`printf` で書き出す）に対して次を確認している。

| ケース | 確認内容 |
|---|---|
| `R ` / `RM` / ` M` / `A ` / ` D` / `??` の混在 | 改名は新パスのみ、他は従来どおり |
| 同上 | 出力に `" -> "` を含む行が無い |
| 同上 | 非ASCIIパスがそのまま返る |
| ` R`（未ステージ側の桁の改名） | 新パスが返る |
| `C `（コピー） | 新パスのみ返り、次のエントリを食わない |
| パス自体が ` -> ` を含む改名 | 新パスが正しく返る |
| `??` が2件連続 | 2件とも返る（改名扱いして食わない） |
| 空入力 | 何も出力しない |
| 旧パスのフィールドが欠けた壊れた入力 | 無限ループせず読めたところまでを返す |

## 受け入れ条件の充足状況

| # | 受け入れ条件 | 結果 | 根拠 |
|---|---|---|---|
| 1 | `" -> "` を含む行が出力されない | ✅ | 上記3（実機）・4（テスト） |
| 2 | `R ` / `RM` の両方で新パスが返る | ✅ | 上記4（フィクスチャ）・1（`RM` は実機でも確認） |
| 3 | 非ASCIIでも壊れない（`core.quotepath=false` の維持） | ✅ | 上記3（実機で日本語名）。`-z` では元から影響を受けないが、コミット済み分の `--name-only` に必要なため指定は維持 |
| 4 | 単体テストが追加され `passed=N failures=0` | ✅ | `passed=140 failures=0`（131 → 140） |
| 5 | 改名が無い場合の既存呼び出し元の出力が従来と同じ | ✅ | 上記3（`git mv` を戻した後の出力が一致）。`resume` / SessionStart hook 側のコードは変更していない |

## 確かめられなかったこと

- **`resume`（`issue-mr-resume` サブエージェント）・SessionStart hookの実際の表示**は、改名がある
  状態でのエンドツーエンド確認をしていない。両者とも `get_branch_work_files` の出力をそのまま
  一覧として提示するだけで、間に加工が無いことをコードで確認するに留めた
  （`.claude/hooks/session-start.sh` の `work_files="$(get_branch_work_files ...)"`、
  `.claude/agents/issue-mr-resume.md` の手順）。
- **git bash（MSYS）実機での確認**は行っていない（本セッションはLinuxのリモート実行環境）。
  ただし追加したのはbash組み込みの `read -d ''` とパラメータ展開のみで、Windowsネイティブの
  実行ファイル（`jq` 等）へパスを渡す処理は含まないため、`.claude/rules/shell-script-style.md`
  が挙げるMSYS固有の落とし穴には該当しない。
- **`C`（コピー）ステータスの実機確認**は行っていない（gitは既定でコピー検出を行わないため、
  `--find-copies` 相当の設定が要る）。フィクスチャでの確認に留めた。改名と同じ2フィールド形式で
  あることはgitのドキュメントに基づく。

## 設計への反映

- 仕様（`.claude/docs/spec/issue-mr-workflow.md`）へ、行単位形式が曖昧である理由と `-z` の
  フィールド順を記載した。**削除されたファイルの扱いは変更していない**ことも明記した
  （issue #115 のスコープ外）。
- 上記「2」で分かった「空白を含むパスはクォートされる」「` -> ` はパスにも現れうる」という
  一般的な落とし穴は、`.claude/rules/shell-script-style.md`「コマンド置換とNULバイト」節へ
  悪い例／良い例つきで一般化した。既に同節にある `git ls-files -z` の項目と並べることで、
  「`ls-files` だけの話」と読まれるのを防ぐ意図がある。
- DDRは起こしていない（比較検討して落とした対案が無く、バグ修正としての一択のため。理由は
  `plans/【設計反映】改名パスの一覧化.md` に記載）。
