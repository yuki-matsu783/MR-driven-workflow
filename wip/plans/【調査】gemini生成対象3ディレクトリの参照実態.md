---
title: 【調査】.gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響
type: plan
description: .gemini/hooks/ scripts/ docs/ を生成対象から外すかを判断するための、参照件数・相対リンクの解決可否・除外時の影響を調べる個別調査計画
tags: [plan, gemini, sync-gemini-assets, 調査]
keywords: [参照件数, 相対リンク, 解決可否, COPY_EXCLUDED_PREFIXES, 除外, 配布, 単体テスト, 死蔵]
---

# 【調査】.gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響

## 前提（合意状況）

- 上位の計画: `wip/plans/mellow-drifting-lantern.md`（全体作業計画。flow-id 1-4 で作成）。
  **非対話セッションのため flow-id 1-5 の人間による合意は得ていない**（進捗記号は `[]` のまま）。
- issue #172 の本文が示す見立て（hooks/ scripts/ は使われない、docs/ は外すとリンクが切れうる）は
  **仮説として扱う**。この調査で件数付きに裏を取ってから採否を決める。

## この計画で何をするか

`.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` の3ディレクトリについて、
**「誰が・どのパスで参照しているか」を件数で確定させる**。判断そのもの（外す／残す）は
フェーズ3で行い、この調査ではその材料だけを揃える。

## 変更対象

調査のみのため、リポジトリのコード・設定は変更しない。生成される成果物は次の2つ。

| ファイル | 操作 | 何をするか |
|---|---|---|
| `wip/reports/20260823_mellow-drifting-lantern_gemini生成対象の参照実態.md` | 新規 | 調査結果の正文（Q1〜Q6の答え） |
| 同名の `.html` | 新規 | 上記の人間レビュー用ビュー |
| `wip/worklogs/20260823_mellow-drifting-lantern_【調査】gemini生成対象3ディレクトリの参照実態_push2.md` | 新規 | 試行錯誤の詳細ログ |

## 方針

**「参照が無い」を主張するには、探し方そのものを結果に書く。** grepのパターン・対象範囲・
除外条件を調査結果へ書き残し、読み手が同じコマンドで再現できるようにする。
0件という結果は、パターンが実データに当たっていないだけでも得られてしまうため
（`.claude/rules/shell-script-style.md`「異常が無ければ何も出ない検証」と同根）。

**そのため、各グレップは「当たることが分かっている対照」とセットで実行する。**
たとえば「`.gemini/scripts/` への参照が0件」を示すときは、同じパターンで
`.claude/scripts/` を検索して非0件が返ることを併記する。パターンが壊れていれば両方0件になる。

**参照の「経路」を3つに分けて数える。** 混ぜると、片方の経路だけで使われているものを
「使われていない」と誤判定する。

| 経路 | 何を見るか |
|---|---|
| 設定からの実行 | `.gemini/settings.json` の hook `command` が指すパス |
| ドキュメント間のリンク | `.gemini/` 配下の md から `../` 等で辿る相対リンクの解決先 |
| 資産からの呼び出し | `.gemini/rules/` `.gemini/skills/` `.gemini/agents/` の本文が指すスクリプトのパス |

## 調査項目

| # | 問い | 答えの形 |
|---|---|---|
| Q1 | `.gemini/hooks/` 配下を指す参照は何件か。変換後の `.gemini/settings.json` の hook `command` は何を指しているか | 件数＋実際のパス一覧 |
| Q2 | `.gemini/scripts/` 配下を指す参照は何件か。`.gemini/` 配下の資産からの呼び出しはどのパスを指しているか | 件数＋対照（`.claude/scripts/` の件数） |
| Q3 | `.gemini/docs/` を解決先とする相対リンクは `.gemini/` 配下に何件あるか。逆に `.gemini/docs/` 配下から `.gemini/` 内の他ファイルへ向かうリンクは何件か | 双方向の件数 |
| Q4 | 3ディレクトリを除外した場合、`.gemini/` 内で解決できなくなる相対リンクは何件になるか | ディレクトリごとの件数 |
| Q5 | 除外を実装する場合、`COPY_EXCLUDED_PREFIXES` の現在の意味論（完全一致）で足りるか。既存テストのどれが影響を受けるか | 要否＋影響テスト名 |
| Q6 | 除外は何をどれだけ減らすか（ファイル数・バイト数・`--check` の所要時間） | 実測値 |

## やらないこと（スコープ外）

- **判断そのもの（外す／残す）を出すこと。** この調査は材料を揃えるまでで、判断はフェーズ3。
- **Gemini CLI 実機でのロード確認。** 実行環境に Gemini CLI が無い（既知の未決定事項）。
- **`.claude/` 側の参照の棚卸し。** `.claude/` からの参照は今回の判断に影響しない
  （`.claude/` は常に生成対象の「元」であって、コピー先ではない）。
- **変換規則（agents frontmatter・settings.json のキー対応）の点検。**

## 検証

```bash
# 各Qのグレップは、対照とセットで実行して結果へ併記する（下記は Q2 の例）
grep -rIn --include='*.md' -e '\.gemini/scripts/' .claude .gemini | wc -l
grep -rIn --include='*.md' -e '\.claude/scripts/' .claude .gemini | wc -l   # 対照（非0であること）

# Q6 の実測
find .gemini/hooks .gemini/scripts .gemini/docs -type f | wc -l
du -sb .gemini/hooks .gemini/scripts .gemini/docs
time bash .claude/scripts/src/sync-gemini-assets.sh --check
```

合格条件:

- Q1〜Q4 に**件数で**答えられている（「無い」ではなく「0件である」）。
- 0件と答えた問いには、**同じパターンで非0件が返る対照**が併記されている。
- 3ディレクトリそれぞれについて「外す／残す」の判断材料（Gemini CLI が読むか・リンクが切れるか・
  除外時に何が壊れるか）が揃っている。

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172 / PR #193。
