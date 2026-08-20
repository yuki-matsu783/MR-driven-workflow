---
title: 【AIアセット反映】ルールとリポジトリマップの更新
type: plan
description: issue #33の個別反映計画（AIアセット反映）。rules・index.md・README・DEVELOPERSの更新範囲
tags: [plan, ai-asset, rules]
keywords: [shell-script-style, directory-structure, index.md, README, DEVELOPERS, gitattributes, VERSION, 未導入]
---

# 【AIアセット反映】ルールとリポジトリマップの更新

全体作業計画: `plans/配布テンプレート資産の整備.md`（issue #33）

`.claude/rules/docs-workflow.md` に従い、`【設計反映】` とはファイルを分ける。設計反映
（`.claude/docs/spec/` `.claude/docs/ddr/` への記録）を終えてからこちらに着手する。

## 反映対象の洗い出し

| 反映先 | 反映する内容 | 受け入れ条件との対応 |
|---|---|---|
| `.claude/rules/shell-script-style.md` | 「`.gitattributes` に `*.sh text eol=lf` を追加する運用も検討できる（未導入）」を、**導入済み**の記述へ更新する | issue #33 受け入れ条件3 |
| `.claude/rules/directory-structure.md` | ツリーへ `.gitattributes`・`.claude/VERSION`・`.github/pull_request_template.md`・`.gitlab/merge_request_templates/` を追加する | — |
| `index.md`（Repository Map） | 同上（役割説明はこちらが正） | — |
| `README.md` | セットアップ節に、配布物の版（`.claude/VERSION`）の位置づけを1〜2行足す | — |
| `DEVELOPERS.md` | `sync-assets.sh` の節に `.gitattributes` が同期対象へ入ったことを反映する | issue #33 受け入れ条件5 |

## 更新の方針

- **`shell-script-style.md` は「未導入」の一文を書き換えるだけにとどめ、`.gitattributes` の
  設計判断そのものはspecへ置いてリンクする**（同じ内容を2箇所で管理しない。ルート
  `REVIEW-POINTS.md` の「同じ内容が複数ファイルに重複して書かれていないか」に対応）。
- **`.claude/rules/directory-structure.md` と `index.md` は役割が違う**（前者はツリー構造・配置
  ルール、後者は役割説明）。同じ説明文を両方へ書かない。
- **main を取り込んだ直後の `shell-script-style.md` を対象にする。** main側（PR #131）で同ファイルへ
  38行の追記が入っているため、取り込み前の内容を前提に書き換えない。

## この計画で決めないこと

- `install-to-project.sh` が追記する `.gitignore` の行が実態と食い違っている問題
  （issue #26 の担当。調査結果に記録済み）。

## 検証

- 「未導入」という語が `.claude/rules/shell-script-style.md` から**無くなっている**こと
  （`grep -c -- '未導入' .claude/rules/shell-script-style.md` が 0）。
- `.gitattributes` が `index.md` と `.claude/rules/directory-structure.md` の両方のツリーに
  現れること（`grep -c` で各1以上）。
- `bash .claude/scripts/src/extract-frontmatter.sh .` が `failed=0` で完了すること。
