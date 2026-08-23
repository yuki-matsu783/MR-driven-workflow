---
title: 'worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push5）'
type: log
description: issue #27 収穫スキル一式の実装（flow-id 3-6 相当）の試行錯誤ログ（push5）
tags: [worklog, harvest]
keywords: [harvest-from-projects.sh, gitignore_matches, アンカー, 生US文字, awk \001, git archive, passed=66]
---

# worklog: 【AIアセット作成】【実装】【テスト】収穫スキルの新設（push5）

対象: issue #27 収穫スキルの実装（2026-08-23）。
全体作業計画: `plans/quiet-orchard-harvest.md`
個別作業計画: `plans/【AIアセット作成】【実装】【テスト】収穫スキルの新設.md`
push回数: 7

## 試したこと

- `harvest-from-projects.sh`（scan / diff / merge3）・SKILL.md・テスト（T1〜T15、
  アサーション66件）・dist-layers の exclude エントリ・markdown-frontmatter.md への
  DDR規約追記を実装した。
- 検証4種（bash -n・テスト・check-dist-coverage・frontmatter 実問い合わせ）を実行し全合格。
  結果の転写は `reports/2026-08-23_quiet-orchard-harvest_作業結果.md`。

## うまくいったこと

- テストが設計どおり境界バグを1件検出した: `gitignore_matches` で `/usage/`（アンカーを
  剥がすとスラッシュが残らないパターン）が任意階層セグメント照合へ流れ `src/usage/` にも
  一致していた。アンカー分岐をセグメント照合の前へ追加して解消（T10）。
- git 起動の一括化（ls-tree 1回・diff-filter=D 1回・log --name-only 1回＋awk・
  archive|tar 1回）が計画どおり実装でき、ファイル数比例の起動は modified core の
  base/ours 実体化と merge-file だけに抑えた。

## ダメだったこと

- jq フィルタの US 区切りを最初**生の 0x1F バイト**でソースへ書いてしまった
  （`shell-script-style.md`「ソースコードへ生の制御文字を書かない」に自分で違反）。
  `cat -v` と `tr -d '\037'` 前後のバイト数比較で検出し、エスケープ表記へ perl で置換した。
  同じ生バイトがレポート md/html へも1つずつ紛れ、Bashツールが「制御文字を含む」として
  コマンドを弾く形で表面化した（規約の言う「ツール経由の編集で弾かれる」をそのまま踏んだ）。
- awk の件名マーカーを `/^\x01/` と正規表現で書きかけた（\x エスケープは処理系依存）。
  POSIX の8進文字列 `"\001"` ＋ `substr` 比較へ変更。
- 計画の frontmatter 検証コマンドが index.jsonl の実スキーマ（`concept_id` /
  `frontmatter.type`）と合っておらず空振りした。検証コマンド自体の実データ確認が要る。

## 次の一歩

- commit・リモート反映 → 敵対的レビュー4回目（フェーズ3・対象=実装一式）→ 指摘反映 →
  フェーズ4（反映計画）へ。

---
