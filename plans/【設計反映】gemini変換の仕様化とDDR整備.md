---
title: 【設計反映】gemini変換の仕様化とDDR整備
type: plan
description: issue #70 の成果をspec・DDR・案内ドキュメントへ反映する計画。sync-gemini-assets.mdの新規作成とi0000-13のsupersedeを含む
tags: [spec, ddr, documentation, issue-70]
keywords: [sync-gemini-assets, i0070-01, i0000-13, setup-gemini-links, changelog, policy-engine, Workspace層, REVIEW-POINTS]
---

# 【設計反映】gemini変換の仕様化とDDR整備

対象: issue #70 / PR #157 / flow-id 4-1

`plans/` `worklog/` `reports/` の内容のうち**恒久的に残すべきもの**を、
`.claude/docs/spec/` `.claude/docs/ddr/` と案内ドキュメントへ移す。
これらは flow-id 5-5 で削除されるため、**移さなかった知見は失われる**。

コードの修正を伴うものは `【実装反映】` が扱う（評価軸が違うため分ける）。

## 対象（8件）

### A. 新規作成

| # | 対象 | 内容 |
|---|---|---|
| 1 | `.claude/docs/spec/sync-gemini-assets.md` | **`sync-gemini-assets.sh` の冒頭が「仕様」としてこのパスを指しているのに、ファイルが無い。** 変換規則（ツール名11組・agentsのキー許可リスト・settingsの写像・hookの `$GEMINI_PROJECT_DIR`・SessionStart matcher省略）、除外規則、3モード（write/`--check`/`--dry-run`）、**フェーズ3で新設した孤児検出と `--force`**、性能上の前提 |
| 2 | `.claude/docs/ddr/i0070-01-….md` | `.gemini/` を生成物にする決定。**却下案**（リンク運用の継続／配布物として配る）とその理由 |

### B. 既存の更新

| # | 対象 | 内容 |
|---|---|---|
| 3 | `.claude/docs/ddr/i0000-13-….md` | frontmatter のみ `status: superseded` / `superseded_by: "i0070-01"`。**本文は変更しない** → `generate-ddr-list.sh` で一覧を再生成 |
| 4 | `.claude/rules/directory-structure.md` L36・L111-119 | リンク運用の説明を、生成物の説明へ差し替える。`setup-gemini-links.sh` の案内を削除 |
| 5 | `index.md` L33-36 / `README.md` L13・L35-36 | 同上（**`README.md` はセットアップ手順なので、新しく入った人が最初に踏む**） |
| 6 | `.claude/docs/spec/issue-mr-workflow.md` | (a)「Gemini CLIのhook登録」節（L1140-1147）を生成物前提へ書き直し、**写像規則の正は `sync-gemini-assets.md` 1箇所**にしてリンクだけ残す (b) `## 未決定事項・懸念点` の issue #57 項目（SessionStart matcher）を**削除** (c) `## 影響範囲` へ `### issue #70` の changelog を追加（flow-id 5-3 新設と 42→43ステップの繰り下げ） |
| 7 | `.claude/docs/spec/search-frontmatter.md` L61 | `.gemini` 除外の理由が旧設計（ジャンクション）のまま。**スクリプト側のコメントだけが更新されていて、正が2つある**（フェーズ3の敵対的レビュー minor 指摘） |
| 8 | `.claude/docs/spec/distribution-assets.md` L159 | 配布対象ディレクトリを4→3へ（`.gemini/` は配布先で生成する） |

### C. 繰り下げ漏れ・その他

| # | 対象 | 内容 |
|---|---|---|
| 9 | `reports/REVIEW-POINTS.md` L26 | `5-4` → `5-5`。**あわせて「`REVIEW-POINTS.md` は `plans/` `reports/` 配下にあっても棚卸しの対象に含める」を残す**（`plans/` `worklog/` `reports/` を一括で対象外にする棚卸しからすり抜けた類型。worklogの「5類型」に対する**6類型目**） |
| 10 | `.claude/docs/spec/cleanup-task.md` L6 | `keywords` の `flow-id-5-4` → `flow-id-5-5`（`title`/`description` は更新済み。`index.jsonl` の検索キーなので逆転が起きる） |
| 11 | `.claude/scripts/test/test_search_frontmatter.sh` L456-457 | 2つのアサーションが同一のコマンド・同一の期待値になっている。`.gemini` 側のフィクスチャを一意な語へ変え、独立に落ちるようにする |

## 必ず残す「制約」（reportsにしか無いもの）

| 事実 | なぜ残すか |
|---|---|
| **policy engine の Workspace 層は現在無効**（`docs/reference/policy-engine.md` L126-130・L144、upstream #18186） | 「スコープ外だから写像しない」と書くと、上流が直れば解決する課題だと読めない。**「今は動かない」**と書く |
| コミット強制の多重防御が **Gemini経路では hook 1枚**になる | 受け入れた制約であることを明示しないと、欠陥として蒸し返される |
| `mcp__github__issue_write` は Gemini CLI に相当ツールが無く、matcher から落ちる | **外部の制約であって実装の欠陥ではない**（`reports/REVIEW-POINTS.md` の観点） |
| **`.gemini/` を Gemini CLI が実際にロードできることは未確認**（CLIがこの環境に無い） | issue #70 の受け入れ条件の未達。**spec の未決定事項へ書く** |
| `read -d ''` の実機計測が未了 | 同上。「測れないから現状維持」であることを明示する |

## この計画で決めないこと（スコープ外）

- `.gitignore` から消えた `i00-13` 参照の扱い。**`i36-01` は別ブロックに残っており、
  どちらも「存在しないDDR名を指すコメント」という同じ欠陥**である。issue #70 の成果とは
  無関係なので、**別issueへ切り出すことを提案する**（AIが独断で起票はしない）。
- `.gemini/hooks/` `.gemini/scripts/` `.gemini/docs/` を生成対象から外すか（敵対的レビューの
  minor 指摘）。**変換規則そのものを変えるので、フェーズ4の反映ではなく別の判断**である。

## 検証

| # | 条件 | 方法 |
|---|---|---|
| 1 | **DDR本文の差分がゼロ** | `git diff <分岐点のSHA> -- .claude/docs/ddr/` の変更行が frontmatter のみ |
| 2 | `.claude/docs/README.md` のDDR一覧が生成物と一致 | `generate-ddr-list.sh` を実行し差分ゼロ |
| 3 | `setup-gemini-links.sh` への参照が0件 | `grep -rn 'setup-gemini-links' --exclude-dir=.git .`（**DDR本文・worklogの過去記録は除く**） |
| 4 | `flow-id 5-4` の繰り下げ漏れが0件 | `grep -rn` し、DDR本文と「当時の番号」注記だけが残ることを確認 |
| 5 | 新規markdownにfrontmatter5キーがある | `search-frontmatter.sh` で引ける |
| 6 | 全16本が緑 | 一括実行 |
| 7 | `.gemini/` 再生成 → `--check` が0 | `sync-gemini-assets.sh --check` |

**3・4は「異常が無ければ何も出ない」形なので、件数を必ず出す**（`.claude/rules/shell-script-style.md`
「テスト」）。0件を期待する検索は、パターンが実データに合っていないと常に成功する。
