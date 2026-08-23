---
title: AIアセット反映の結果（ディレクトリ構成とRepository Map）
type: report
description: ツリーとRepository Mapから欠落していた3件を埋め、.claude/VERSION を 0.2.0 のまま据え置いた結果
tags: [report, AIアセット反映, directory-structure, version]
keywords: [directory-structure, index.md, Repository Map, agent-common, check-dist-coverage, asset-manifest, VERSION据え置き, 罫線]
---

# AIアセット反映の結果: ディレクトリ構成とRepository Map

flow-id 4-6（`【AIアセット反映】`。フェーズ4の3セット目・最後）。計画は
`plans/【AIアセット反映】ディレクトリ構成とVERSIONの更新.md`。

## 結論

**案内から抜けていた3件を埋め、`.claude/VERSION` は触っていない。**

| ファイル | 反映前 | 反映後 |
|---|---|---|
| `.claude/rules/directory-structure.md`（ツリー） | 3件とも無い | `agent-common.md` / `check-dist-coverage.sh` をツリーへ、`.asset-manifest.json` を説明文へ |
| `index.md`（Repository Map） | `agent-common.md` / `.asset-manifest.json` が無い | どちらも追加 |
| `.claude/VERSION` | `0.2.0` | **`0.2.0`（差分なし）** |

`.claude/docs/README.md` への新設 spec の追加は、**`【設計反映】` で済ませてある**
（このセットでは触っていない）。

## 1. 埋めた欠落

### `agent-common.md`（**ツリーにも Repository Map にも無かった**）

本issueが新設した `core` のルールファイルで、`AGENTS.md` / `CLAUDE.md` / `GEMINI.md` の3つが
これを `@import` している。**「AIが読むもの」の正が、案内のどこからも辿れない状態**だった。

- ツリー: `rules/` の子として、`@import` の実体であることと配布層（`core`）を添えた。
- Repository Map: `rules/` の子項目として追加し、**3つのファイルへ写しを持たせないための構造**である
  ことを明記した（役割説明は Repository Map 側が正、という
  `directory-structure.md` 冒頭の分担に従っている）。

### `check-dist-coverage.sh`（ツリーに無かった）

Repository Map には `dist-layers.json` の説明の中で既に触れられていたが、ツリーには無かった。
`scripts/src/` の子として追加した。

### `.asset-manifest.json`（**ツリーに載せてはいけないもの**）

**配布先にだけ生成されるため、このリポジトリには実体が無い。** ツリーへ載せると本家にも在ると
誤読されるので、`reports/` `usage/` `.claude/state/` と同じく**ツリー直後の説明文**へ書いた
（`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」と同じ考え方で、
挿入位置は「動的に作られるもの」の段落の直後を選んでいる）。

Repository Map 側も、他の行と違って**リンクにしていない**（実体が無いのでリンクが切れる）。
その理由も1行添えた。

## 2. `.claude/VERSION` は変更していない

**flow-id 4-4 のレビューで `0.2.0` 据え置きが確定している**ため、この計画では触っていない。

- `git diff --stat .claude/VERSION` が**空**であることを検証項目として流した（計画の自己点検が
  「差分が出ていたら範囲外の変更が混ざっている」と定めていたもの）。
- **`AskUserQuestion` は行っていない。** 増分を決めるのは人間だが、**その決定は既に下りている**
  ため、実施時に重ねて聞かない（計画の指示どおり）。
- 据え置いた事実の changelog への記録は、**`【設計反映】` で済ませてある**
  （`distribution-assets.md` の `### issue #26（2026-08-23）`）。このセットの成果物ではない。

## 検証

| 検証 | 結果 |
|---|---|
| 1. 欠落が埋まったこと | `check-dist-coverage.sh` / `agent-common.md` / `asset-manifest` の3件とも **ds=1 idx=1**（反映前は ds=0 が3件・idx=0 が2件） |
| 2. ツリーの罫線 | 目視で確認。差し込んだ2箇所の前後を読み、親子関係が崩れていないこと |
| 3. frontmatterインデックス | 再生成 `files=150 built=3 reused=147 failed=0` |
| 4. 網羅性チェック | 追跡ファイル **226/226** 件・`.gitignore` 13/13 行・空振り0件・不正0件 |
| 5. 単体テスト | 18ファイル / **`passed=1147 failures=0`** |
| **`.claude/VERSION` の差分** | **無し**（据え置きが確定しているため、差分が出たら異常） |

網羅性の分母が 221 → 226 に増えているのは、このセットで計画/レポートの md・html を足したためで
ある（ファイルの追加は案内の更新とは無関係）。

## 計画との差分

| 計画 | 実際 |
|---|---|
| 新設 spec のファイル名を確認してからツリーへ書く | **ツリーへは書かなかった。** ツリーは `spec/` をディレクトリ単位でしか持たず、個別の spec を列挙していない。新設 spec の案内は `.claude/docs/README.md` の spec 一覧が担い、**それは `【設計反映】` で追加済み** |
| ツリー・Repository Map の欠落3件を埋める | 3件に加えて、**Repository Map のスキル一覧へ3件を追加した**（下記） |

### 計画に無かった追加（明示しておく）

`index.md` のスキル一覧が `/issue-mr-flow`・`/commit`・`/issue-create`・`/resolve-conflict`・
`/canvas-report`・`/doc-search` の6つしか挙げておらず、**`/apply-mr-workflow-to-project`が
抜けていた**。本issueの主題そのもののスキルが Repository Map から辿れないのは
`agent-common.md` と同じ類型の欠落なので、あわせて追加した。**同じ行にあった
`/adversarial-review`・`/review-points` の欠落も、1行の編集で済むため同時に埋めている。**

**これは計画に書いていない変更である。** 不要と判断されれば戻せる（該当は `index.md` の1行のみ）。

## 触らなかったもの

- **`.claude/VERSION`**（上記）。
- **`.claude/docs/README.md`**（`【設計反映】` で更新済み。二重に触らない）。
- **フェーズ3で反映済みの3件**（`ai-asset:` prefix 規約 → `commit` スキル、`assets/` の位置づけ →
  `directory-structure.md` 142〜144行目、`requiredLine` の扱い →
  `apply-mr-workflow-to-project/SKILL.md`）。計画の「既に済んでいるもの」の表どおり、再度触っていない。
