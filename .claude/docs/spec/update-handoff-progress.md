---
title: HANDOFF進捗自動更新スクリプト（update-handoff-progress.sh）
type: spec
description: HANDOFF.mdの進捗表の記号・ヘッダ情報を機械的に更新するdev-toolスクリプトの仕様
tags: [update-handoff-progress, handoff, spec]
keywords: [update-handoff-progress, flow-id, 進捗表, ループ範囲, mark-done, mark-skip, add-round, set-header]
---

# HANDOFF進捗自動更新スクリプト（update-handoff-progress.sh）

## 背景・目的

issue #20対応。`.claude/rules/docs-workflow.md`と`.claude/skills/issue-mr-flow/SKILL.md`は
「flow-idが1つ進むごとに`HANDOFF.md`を更新し、commitより前に同じcommitへ含める」ことを求めているが、
更新はメインエージェントの手作業に依存していた。進捗表は39行あり、記号の規則（ループ扱いのステップは
往復1回につき`[]`を1つ追加し、同じループ範囲内のステップは常に同数を保つ）も細かいため、書き間違い・
更新漏れが起きやすい。これを解消するため、進捗表の記号・ヘッダ情報の更新を機械化した。

## 仕様

### 実行方法

```bash
bash .claude/scripts/src/update-handoff-progress.sh mark-done <flow-id> [--file <path>]
bash .claude/scripts/src/update-handoff-progress.sh mark-skip <flow-id> [<flow-id>...] [--file <path>]
bash .claude/scripts/src/update-handoff-progress.sh add-round <flow-id> [--file <path>]
bash .claude/scripts/src/update-handoff-progress.sh set-header [--issue <text>] [--branch <text>] \
  [--pr <text>] [--push-count <n>] [--file <path>]
```

`--file <path>`は全サブコマンド共通のオプションで、操作対象ファイルを切り替える（省略時
`HANDOFF.md`）。テストからフィクスチャファイルを指定する用途を想定している。

### 進捗記号とループ範囲

進捗記号は`[x]`（完了）/ `[]`（未着手・進行中）/ `[-]`（今回は実施しない・スキップ）の3種類
（`.claude/rules/docs-workflow.md`参照）。

ループ扱いのflow-id（「〜を合意まで繰り返す」と書かれたステップ）は、レビュー往復1回につき`[]`/`[x]`
を連結して持つ（例: `[x][x][]`）。ループ範囲は以下の6つで、スクリプト内に定数
（`LOOP_RANGES`）として保持している。範囲・並びを変える場合は`.claude/rules/docs-workflow.md`と
両方を更新すること。

```
2-3 2-4
2-6 2-7 2-8 2-9
3-3 3-4
3-6 3-7 3-8 3-9
4-3 4-4
4-6 4-7 4-8 4-9
```

同じループ範囲内のflow-idは常に同じ個数の`[]`/`[x]`を持つ、という既存ルールを機械的に保証するため、
`mark-done`/`add-round`はループ範囲に属するflow-idを操作する際、**範囲内の全flow-id行へ同じ操作を
一括適用する**。

### サブコマンド

| サブコマンド | 挙動 | エラー条件 |
|---|---|---|
| `mark-done <flow-id>` | 対象行（ループ範囲なら範囲内の全flow-id行）の進捗列**末尾の`[]`**を`[x]`に置き換える | 対象行のいずれかで末尾が`[]`でない場合（既に完了済み等） |
| `mark-skip <flow-id> [<flow-id>...]` | 指定した各flow-id行の進捗列を`[-]`へ丸ごと上書きする（複数指定可） | 指定flow-idの一部が表に見つからない場合 |
| `add-round <flow-id>` | ループ範囲内の全flow-id行の進捗列**末尾に新しい`[]`を追記**する（次の往復が始まったことを表す） | 対象flow-idがループ範囲に属さない場合／対象行のいずれかで末尾が既に`[]`の場合（前回往復が未完了） |
| `set-header` | `--issue`/`--branch`/`--pr`/`--push-count`のうち指定されたオプションのみ、対応するヘッダ行（`- issue: `等で始まる1行）を書き換える。未指定の項目は現状維持 | — |

### 制約・設計判断

- **ループ範囲は「1周（レビュー往復1回）が完全に完了して初めて`[x]`にする」という設計であり、
  範囲内の一部ステップだけを個別に完了扱いにすることはできない。** `mark-skip`で範囲内の一部を
  先に`[-]`にすると、その後の同じ範囲への`mark-done`/`add-round`は「末尾が`[]`でない」エラーで
  拒否される。これは実装のバグではなく、`.claude/rules/docs-workflow.md`の「同じループ範囲内の
  ステップは常に同じ個数の`[]`を持つ」というルールを機械的に強制した結果であり、意図した挙動である
  （実機確認: issue #20対応中、前issue #13のHANDOFF.mdがこのルールに反する手作業更新をしていた
  ことがこの過程で判明した）。
  - ループ範囲の一部だけ実施し残りを省略する場合（非対話的実行環境でのレビュー省略等）は、進捗記号を
    `[]`のまま残し、実施した内容は「やったこと」等の文章セクションで補足する運用とする。
- ヘッダ各項目（issue/ブランチ/PR/push回数）は1行である前提で実装している。説明の補足等で2行目
  以降に折り返している場合、`set-header`は1行目のみを書き換え、2行目以降はそのまま残る。
- 進捗表の書き換えは、Markdownテーブル行を正規表現でprefix（進捗列より前）・progress（進捗列の
  中身）・suffix（進捗列より後、flow-id列を含む）の3区画へ分解し、単純な文字列連結で再結合する
  方式を採る。bashのパターン置換（`${line/pattern/repl}`）は使わない。`[x]`のような進捗記号が
  globの文字クラスとして誤解釈される事故を避けるためである。
- HANDOFF.mdを直接テキスト処理で書き換える方式を採用し、進捗状態を別のJSON/YAML等の構造化
  データへ移行する設計は採らなかった。既存の`HANDOFF.md`の構成（見出し・表の列）を人間にも読み
  やすいMarkdownのまま壊さない、という要件を素直に満たせるため。

### テスト

`tests/test_update_handoff_progress.sh`が、簡略版HANDOFF.mdフィクスチャに対する各サブコマンドの
挙動（正常系・エラー系）を検証する（`.claude/rules/shell-script-style.md`「テスト」の
`passed=N failures=N`規約）。`tests/test_vcs_provider.sh`と同様、スクリプトの関数を直接sourceして
呼び出す方式で、外部プロセスの起動を伴わない。

## 影響範囲

- `.claude/skills/issue-mr-flow/SKILL.md`: 「flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する」
  手順から、本スクリプトの呼び出しへ委譲する記述を追加した。
- `.claude/rules/docs-workflow.md`: `[-]`記号の正式ルール化、非対話的実行環境でのループ範囲運用
  ルールを追記した。

## 未決定事項・懸念点

- ループ範囲テーブルは`update-handoff-progress.sh`と`.claude/rules/docs-workflow.md`の2箇所に
  同じ内容を保持しており、片方だけ更新すると不整合が生じる。将来flow-idの構成が変わる場合は
  両方の更新が必要。
