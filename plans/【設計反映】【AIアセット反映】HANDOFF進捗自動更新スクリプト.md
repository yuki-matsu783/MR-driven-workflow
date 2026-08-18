---
title: 【設計反映】【AIアセット反映】HANDOFF進捗自動更新スクリプト
type: guide
description: update-handoff-progress.shの成果をspec/ルール/スキルへ反映する個別反映計画
tags: [handoff, automation, docs-workflow, issue-mr-flow]
keywords: [update-handoff-progress, docs-workflow, issue-mr-flow, DDR, spec]
---

# 【設計反映】【AIアセット反映】HANDOFF進捗自動更新スクリプト

全体作業計画: `plans/shiny-puzzling-umbrella.md`

種別を併記する理由: 設計反映（新規spec作成）とAIアセット反映（ルール・スキル更新）が同一の
成果物（`update-handoff-progress.sh`）に対する反映であり、内容的に分離する意味が薄いため
（1回の合意で完結させる）。

## 対象ファイル

- 新規: `.claude/docs/spec/update-handoff-progress.md`
- 更新: `.claude/rules/docs-workflow.md`
- 更新: `.claude/skills/issue-mr-flow/SKILL.md`
- 新規: `.claude/docs/ddr/0024-<タイトル>.md`（要否を反映作業時に判断）

## 反映内容

### 1. 新規spec `.claude/docs/spec/update-handoff-progress.md`

`.claude/docs/spec/extract-frontmatter.md` を雛形に、以下を記載する。

- 背景・目的（issue #20）
- サブコマンド仕様（`mark-done`/`mark-skip`/`add-round`/`set-header`の引数・挙動・エラー条件）
- ループ範囲テーブルの管理方法（`.claude/rules/docs-workflow.md`の6範囲と同期させる必要がある旨）
- 制約・未決定事項:
  - 進捗表の行の物理配置がSKILL.mdの表と同期している前提（行の並び順が変わると動作に影響しない
    設計だが、flow-id自体の追加・削除にはスクリプト側の追従が不要な設計であることを明記）
  - ヘッダ各項目は1行前提（複数行に折り返した補足説明は書き換え対象にならない）
  - **ループ範囲は「1周（レビュー往復1回）が完全に完了して初めて`[x]`にする」という設計であり、
    範囲内の一部ステップだけを個別に完了扱いにすることはできない**（`mark-skip`で範囲内の一部を
    先に`[-]`にすると、その後の`mark-done`/`add-round`がエラーになる。これは意図した挙動であり、
    バグではない）。範囲の一部だけ実施し残りを省略する場合（非対話的環境等）は、記号を`[]`の
    まま残し、「やったこと」等の文章セクションで実施内容を補足する運用とする
    （下記2.の運用ルールとあわせて記載）。

### 2. `.claude/rules/docs-workflow.md` の更新

- `[-]`（今回は実施しないフェーズ）の記号を、`HANDOFF.md`内の既存の凡例
  （`進捗記号: `[x]` 完了 / `[]` 未着手・進行中 / `[-]` 今回は実施しない（スキップ）`）を踏まえて
  正式なルールとして明文化する。用途は「フェーズ単位・ループ範囲単位でまとめて実施しない」ケース
  （例: フェーズ2を丸ごと省略）であり、ループ範囲内の一部ステップだけを`[-]`にする使い方は
  想定しない（1.の制約と平仄を合わせる）ことを明記する。
- **非対話的実行環境（Claude Code on the webのリモート実行環境等）でレビュー待ちステップ
  （人間担当のflow-id）を省略する場合の運用ルール**を新設する。今回の実装検証で判明した内容
  （ループ範囲は範囲全体の往復完了でしか`[x]`にできない）を踏まえ、「レビューステップを省略する
  場合、該当ループ範囲の記号は`[]`のまま残し、実施した内容は『やったこと』セクションで説明する」
  という方針を明記する。

### 3. `.claude/skills/issue-mr-flow/SKILL.md` の更新

- 「flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する」の手順を、`update-handoff-progress.sh`
  の呼び出しへ委譲する形に書き換える（サブコマンド例を添える）。
- 手作業でのテーブル編集は許容しつつ、機械的な記号更新はスクリプト経由を推奨する旨を明記する
  （HANDOFF.md自体はMarkdownとして人間にも読みやすい必要があるため、スクリプトの利用を強制は
  しない）。

### 4. DDRの要否

「HANDOFF.mdを直接テキスト処理で書き換える」方式を採用し、進捗状態を別のJSON/YAML等の構造化
データへ移行する案は採らなかった、という判断を DDR 0024 として記録するか、反映作業時に最終判断
する（既存の受け入れ条件「既存の`HANDOFF.md`の構成を壊さない」から見て、直接書き換え方式は
自明に近い選択であり、DDR化するほどの対立案検討ではない可能性もある）。

## 検証方法

- 新規spec・更新後のルール/スキルファイルについて `bash .claude/scripts/src/extract-frontmatter.sh .`
  を実行し `index.jsonl` が正しく更新されることを確認する。
- `.claude/skills/issue-mr-flow/SKILL.md` の変更後、記述に矛盾がないか通読で確認する。
