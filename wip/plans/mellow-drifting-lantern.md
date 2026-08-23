---
title: 全体作業計画 — .gemini/ の生成対象からhooks/ scripts/ docs/を外すかを判断する（issue #172）
type: plan
description: .gemini/ の生成対象に hooks/ scripts/ docs/ を含めるかを判断し、理由を記録するissue #172の全体作業計画
tags: [plan, gemini, sync-gemini-assets, issue-mr-flow]
keywords: [gemini, 生成対象, hooks, scripts, docs, 相対リンク, sync-gemini-assets, 判断の記録, 配布, DDR]
---

# 全体作業計画 — .gemini/ の生成対象からhooks/ scripts/ docs/を外すかを判断する（issue #172）

> **この全体作業計画は planツール（Planモード）で作っていない。** 非対話セッションで、既にPlanモードを
> 抜けた状態から着手したためハーネスからの自動命名の提示が無く、ファイル名（`mellow-drifting-lantern`）は
> 命名規則に沿ってAIが付けた。`.claude/rules/agent-common.md`・`references/planning.md` からの逸脱
> なので、その事実をここへ残す（`HANDOFF.md` は flow-id 5-5 でリセットされ、この記録が消えるため）。

## この計画で何をするか

`.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` の3ディレクトリそれぞれについて、
`sync-gemini-assets.sh` の生成対象に含めるかを**判断し、その理由を記録する**。
現状維持（3つとも含める）を選んでもよいが、その場合も「判断した結果である」ことが
後から読み取れる形で `.claude/docs/spec/sync-gemini-assets.md` に残す。

## 変更対象

どのファイル群へ手を入れるかの粒度で書く（個別のファイル・行はフェーズごとの個別計画で確定させる）。

| 領域 | 想定する変更 |
|---|---|
| `.claude/docs/spec/sync-gemini-assets.md` | 判断結果と理由の記録（**どの結論でも必ず変更する**） |
| `.claude/docs/ddr/i0172-01-….md` | 判断の背景・却下案の記録（新規） |
| `.claude/scripts/src/sync-gemini-assets.sh` | 除外する判断をした場合のみ、除外定義を変更 |
| `.claude/scripts/test/test_sync_gemini_assets.sh` | 同上（除外を固定するテストの追加） |
| `.gemini/` 配下 | 除外する判断をした場合、再生成の結果として差分が出る |

## 方針

判断を「なんとなく」ではなく、**3つの独立した軸**で行う。

1. **Gemini CLI がそのパスを読むか**（読まないなら複製は死蔵）
2. **`.gemini/` 側だけを見る読み手（配布先・Gemini CLI セッション）がリンクを辿れるか**
3. **除外したときに何が壊れるか**（`--check`・配布・既存テスト）

3ディレクトリを一括で決めず、**1つずつ独立に結論を出す**。issue本文の見立て
（hooks/ scripts/ は使われない、docs/ は外すとリンクが切れうる）は仮説として扱い、
フェーズ2で件数付きで検証してから採否を決める。

**issueは分割しない。** 受け入れ条件は3ディレクトリという同型項目の並列列挙であり、各項目は
単独でマージされてもシステムが壊れない（1件あたりの作業は spec/DDR への追記と除外定義1行）。
`wip/plans/REVIEW-POINTS.md`「issue分割のトリガー」に照らして判定した結果、
**1件あたりの本体が極小で、5フェーズを3回まわす固定費のほうが上回る**ため分割しない
（`references/planning.md`「分割しない条件」の「分割コストが本体を上回る」に該当）。

## フェーズ2〈調査〉

次の問いに答える。いずれも**件数を伴う形**で答えること（「無い」ではなく「0件である」）。

- Q1: `.gemini/hooks/` 配下のスクリプトを指す参照は、リポジトリ全体で何件あるか。
  変換後の `.gemini/settings.json` の hook `command` は何を指しているか。
- Q2: `.gemini/scripts/` 配下を指す参照は何件あるか。`.gemini/` 配下の資産
  （rules・skills・agents）からの呼び出しはどのパスを指しているか。
- Q3: `.gemini/docs/` を解決先とする相対リンクは `.gemini/` 配下に何件あるか。
  逆に `.gemini/docs/` 配下から `.gemini/` 内の他ファイルへ向かうリンクは何件あるか。
- Q4: 3ディレクトリを除外した場合、`.gemini/` 内で解決できなくなる相対リンクは何件になるか
  （hooks/ scripts/ を外したときの影響も、docs/ と同じ尺度で数える）。
- Q5: 除外を実装する場合、`COPY_EXCLUDED_PREFIXES` の現在の意味論（完全一致）で足りるか、
  接頭辞一致への拡張が要るか。既存テストのどれが影響を受けるか。
- Q6: 除外は何をどれだけ減らすか（`.gemini/` のファイル数・バイト数、`--check` の所要時間）。
  現状の実測値はどれくらいか。**「配布物のサイズ」は減らない**——`.claude/dist-layers.json` は
  `.gemini` を `layer: exclude` と定義しており、`.gemini/` はそもそも配られない（配布先で
  `install-to-project.sh` が `sync-gemini-assets.sh` を実行して生成する）。減るのは
  **配布先で生成される `.gemini/` のサイズ**であって、配布物のサイズとは別物である。

**次へ進める条件**: Q1〜Q4 に件数で答えられ、3ディレクトリそれぞれについて
「外す／残す」の判断材料が揃っていること。

## フェーズ4〈反映〉

反映対象は flow-id 4-1 で洗い出す。現時点の見込みは次のとおり（確定した反映内容ではない）。

- `.claude/docs/spec/sync-gemini-assets.md` — 判断結果と理由（**必須**。issueの受け入れ条件）
- `.claude/docs/ddr/` — 判断の背景・却下案を新規DDRとして記録
- `.claude/docs/README.md` — DDR一覧の再生成（`generate-ddr-list.sh`）
- AIアセット（`.claude/rules/directory-structure.md` の `.gemini/` の説明など）— 除外する判断を
  した場合、`.gemini/` の構成の記述が古くならないか確認する
- `.claude/scripts/src/check-doc-references.sh` と `.claude/docs/spec/check-doc-references.md` —
  `.gemini/scripts/` を外す判断をした場合、`CHECK_DOC_REFERENCES_EXCLUDED_DIRS` の
  `".gemini/scripts/test/"` と同 spec の除外表が**存在しないディレクトリを指す死んだ設定**になる
- `.claude/scripts/test/test_search_frontmatter.sh` — `.gemini/docs/…` を引数に取るアサーションが
  あるため、除外する判断をした場合に影響が無いかを確認する

## やらないこと（スコープ外）

- **変換規則そのもの（agents の frontmatter・settings.json のキー対応）の変更**。
  issue #172 が扱うのは「コピー対象に何を含めるか」だけである。
- **Gemini CLI の実機での動作確認**。この実行環境に Gemini CLI が無い
  （`.claude/docs/spec/sync-gemini-assets.md`「未決定事項・懸念点」に既知として記録済み）。
- **`.gemini/` を Git 管理から外すかの再検討**。issue #70 の DDR `i0070-01` が決めた事項で、
  本issueの対象外。
- **`permissions` の変換**（policy engine の Workspace 層待ち。同 spec の未決定事項）。

## 検証

issue全体として、次がすべて満たせたら完了とする。

- `bash .claude/scripts/src/sync-gemini-assets.sh --check` が終了コード0
- `bash .claude/scripts/test/test_sync_gemini_assets.sh` が `passed=N failures=0`
- 3ディレクトリそれぞれについて、判断と理由が `.claude/docs/spec/sync-gemini-assets.md` にある
- 外す判断をしたディレクトリについて、**切れる相対リンクの件数と、その扱い（許容する／リンクを
  書き換える／外さない）**が記録されている。**「1件も切れてはならない」とは読まない**——
  `.gemini/rules/` から `../docs/` へ向かうリンクだけで実測17件あり、その読み方だと
  「docs/ を外す」という結論だけが検証条件によって先に封じられ、「3ディレクトリを1つずつ
  独立に結論を出す」という方針と噛み合わなくなるため（issue #172 の受け入れ条件
  「相対リンクが切れていないことを件数付きで確認している」の解釈を、ここで1つに固定する）

## issueの受け入れ条件との対応

| issue #172 の受け入れ条件 | 対応するフェーズ |
|---|---|
| 3つのディレクトリそれぞれについて、生成対象に含めるかの判断と理由が記録されている | フェーズ2〈調査〉→ フェーズ3〈作業〉→ フェーズ4〈反映〉 |
| 外す判断をした場合、スクリプトとspecが更新され単体テストが `failures=0` で通る | フェーズ3〈作業〉 |
| 外す判断をした場合、相対リンクが切れていないことを件数付きで確認している | フェーズ2〈調査〉Q3・Q4 → フェーズ3〈作業〉の検証 |
| 現状維持とした場合も理由が spec に残っている | フェーズ4〈反映〉 |
| `sync-gemini-assets.sh --check` が0で終わる | フェーズ3〈作業〉の検証 |

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172。
