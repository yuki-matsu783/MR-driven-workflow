---
title: worklog 20260818 extract-frontmatter設計反映・AIアセット反映 push4
type: log
description: issue #11 フェーズ4（反映）の計画立案と実施記録。specの記述誤り2件の発見とDDR 0021新設を含む（push4）
tags: [worklog, extract-frontmatter, 設計反映]
keywords: [個別反映計画, spec, ddr, 0021, リンク切れ, 0008, shell-scripts, flow-id 5-1, index.jsonl, AIアセット]
---

# worklog: 【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性

対象: issue #11 フェーズ4（反映）の計画立案と実施（2026-08-18）。
全体作業計画: `plans/lexical-stirring-peach.md`
個別反映計画: `plans/【設計反映】【AIアセット反映】extract-frontmatter高速化と中断耐性.md`
push回数: 4

## 試したこと

### flow-id 3-10（MR description更新）

未解決スレッドが0件であることを `get_mr_unresolved_comments 19 true` で再確認したうえで
（返ってきたのは自動投稿の対応工数レポートのみ、`threadId=` を含む行は0件）、
PR #19 のdescriptionをフェーズ3完了時点の内容へ更新した。

- `get_mr_unresolved_comments` の出力は**JSONではなく人間可読テキスト**であるため、
  `jq` へ直接パイプすると `parse error: Invalid numeric literal` になる。件数確認は
  `grep -c '^\[comment\]'` / `grep 'threadId='` で行う。
- `get_mr_for_branch` は**JSONオブジェクト**を返すため、MR番号は `| jq -r '.number'` で取り出す
  （生の番号ではない）。

### flow-id 4-1（個別反映計画の作成）

反映元となる確定事項をA〜Iとして整理し、設計反映（spec更新・DDR新設）とAIアセット反映
（rules 2件・SKILL 1件・docs-workflow 1件）に割り付けた。種別は**併記**とした
（同じ実装結果から導かれるドキュメント更新で、分けても合意の単位が変わらないため）。

### flow-id 4-6（反映の実施）

| 対象 | 内容 |
|---|---|
| `.claude/docs/spec/extract-frontmatter.md` | 「差分スキップ（mtimeキャッシュ）」「原子的更新と中断耐性」「性能」の3節を新設。実行方法へ `--force`・`files=/built=/reused=` を追記。中間表現（4種別の表）と `--rawfile` フォールバックを追記。走査方式へ一時ディレクトリの扱いを追記。影響範囲へissue #11エントリを**新規追記**。未決定事項の既知バグを「解消（再現せず）」へ書き換え、`index.jsonl` の陳腐化運用を懸念点として追加 |
| `.claude/docs/ddr/0021-….md` | 新設。採用案＋却下案4件（yq必須依存化／全ファイル一括jq／純bashでjq排除／markdownが無くなったディレクトリの `index.jsonl` 自動削除） |
| `.claude/docs/README.md` | DDR一覧へ0021を追加 |
| `.claude/rules/shell-script-style.md` | 「外部プロセス起動のコスト」節を新設 |
| `.claude/rules/markdown-frontmatter.md` | 再生成手順に `--force` の使いどころ・commit直前実行を追記 |
| `.claude/skills/issue-mr-flow/SKILL.md` | flow-id 5-1の行を更新し、「flow-id 5-1での `index.jsonl` の扱い」節を新設。マージ先行時の対処手順にも同内容を反映 |
| `.claude/rules/docs-workflow.md` | `plans/` 行の運用欄に `plans/index.jsonl` の削除を追記 |

## うまくいったこと

- **反映先の実在確認を計画段階で済ませたことで、既存specの記述誤り2件を早期に拾えた。**
  反映作業に入ってから気づくより手戻りが小さかった。
  - `.claude/docs/spec/extract-frontmatter.md` の未決定事項が
    `.claude/scripts/docs/spec/shell-scripts.md` を参照していたが、**実体は
    `.claude/docs/spec/shell-scripts.md`**（issue #24 の移動時に、現在状態を説明する節が追随して
    いなかった）。→ 修正した。
  - 同specが2箇所で参照する `../ddr/0008-frontmatter抽出スクリプトの設計判断.md` が
    **このリポジトリに存在しない**。`.claude/docs/README.md` に「移植元のDDR 0001・0002・0008・0015は
    持ち込んでいない（連番の欠番はこのため）」と明記されており、意図的な欠番だと確認できた。
    → 新設したDDR 0021 の該当箇所（却下案1: yqを必須依存にしない判断）へ参照を差し替えた。
    なお **DDR 0016 の本文にも `0008` への言及が残っているが、DDR本文は変更不可のため触っていない**。
- 新設DDRの番号は既存の最大 `0020` の次で **`0021`**。
- **過去changelogの保護を機械的に確認した**（`.claude/rules/docs-workflow.md` の
  point-in-time 記録の扱い）。`git diff` で spec の issue #24 / #54 エントリと既存DDR本文に
  変更が入っていないことを確認済み。
- 検証結果:
  - `bash tests/test_extract_frontmatter.sh` → `passed=17 failures=0`
  - `bash .claude/scripts/src/extract-frontmatter.sh .` → `files=51 built=7 reused=44` / **6.4秒**
    （DDR新設・rules更新の分だけ再解析が走った。差分なしなら約2秒）
  - 追加・変更した相対リンクの参照先がすべて実在すること（リンク切れ0件）

## ダメだったこと

- `.claude/rules/shell-script-style.md` に追加した代替表で、セル内に `|`（パイプ）を含む
  コマンド例を書いたため、markdownの表が壊れた。`\|` へエスケープして修正した。
- このマシンの git bash には **`python` は Python 2 系しか無く、`python3` も存在しない**。
  日本語を含むファイルの部分書き換えに `python -c` を使おうとして
  `SyntaxError: Non-ASCII character ... but no encoding declared` になった。
  **テキスト編集は `sed` / Edit ツール / heredocでの全文書き直しで行う**こと。

## 次の一歩

- flow-id 4-7: commit・pushしてレビュー依頼（push4）。
- flow-id 4-8〜4-10: レビュー → 修正 → MR description更新。
- **flow-id 5-1で `plans/index.jsonl` も削除する**（今回SKILL.mdへ手順を明文化した内容を、
  自分自身の片付けでそのまま実行する）。

---
