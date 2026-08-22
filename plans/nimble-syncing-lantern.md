---
title: issue #70 全体作業計画 — .gemini/を.claude/からの変換生成物へ改める
type: plan
description: .gemini/配下をリンク運用から.claude/を正とする変換生成物へ改め、agents・settings.jsonの記法差を吸収する全体作業計画
tags: [issue-mr-flow, gemini, sync, plan]
keywords: [gemini, 変換生成物, sync-gemini-assets, settings.json, agents, tools, リンク運用廃止, DDR, flow-id, 冪等]
---

# issue #70 全体作業計画

`.gemini/` 配下を「`.claude/` 配下へのローカルリンク」から「`.claude/` を正とする**変換生成物**
（Git管理下の実体）」へ改める。あわせて、Gemini CLI が Claude Code 固有の記法を解釈できない問題
（`agents/*.md` の `tools`・`model`、`settings.json` のキー構造）を、変換スクリプト側で吸収する。

- issue: <https://github.com/yuki-matsu783/MR-driven-workflow/issues/70>
- PR: <https://github.com/yuki-matsu783/MR-driven-workflow/pull/157>
- **スコープの正は issue #70 の2番目のコメント**（2026-08-20 の「方針転換」）である。issue本文は
  当初の症状報告（`Agent loading error`）のみで、途中で切れている。

## 前提・制約（先に確認した事実）

| 事項 | 確認結果 |
|---|---|
| 現在の `.gemini/` の実体 | `settings.json` の**1ファイルのみ**（Git管理下）。リンクは未生成 |
| `.gitignore` の除外行 | `/.gemini/{docs,hooks,rules,scripts,skills}` の5行。**`agents` は含まれていない** |
| `setup-gemini-links.sh` の `TARGETS` | `(docs hooks rules scripts skills)`。**`agents` を含まない** |
| `.claude/agents/` の定義 | `issue-mr-resume.md` / `adversarial-reviewer.md` の2件。いずれも `tools: Read, Grep, Glob, Bash` と `model: sonnet`／`opus` を持つ |
| **Gemini CLI** | **この実行環境にインストールされていない**（`command -v gemini` が空）。**実機確認ができない** |
| ブランチ名 | ハーネスの指定により `claude/gemini-to-claude-migration-jc64gu`。`.mrworkflow.json` の `feature-{issue}-{slug}` 規約とは異なるが、ハーネス側の指示が優先される |

### 実機確認ができないことの帰結（最重要）

issue #70 の受け入れ条件のうち、次の2件は**この環境では検証できない**。

- 「`Agent loading error: tools.0: Invalid tool name` が再現しない」
- 「`.gemini/settings.json` の hook が Gemini CLI 実行時に発火する」

したがって本タスクは、**変換規則を「外部の一次情報（Gemini CLI の公式ドキュメント・スキーマ）に
基づいて確定し、変換の入出力を単体テストで固定する」ところまで**を成果物とする。実機での発火確認は
**受け入れ条件の未達項目として明示し、別issueへ切り出すか、ユーザーのローカル環境での確認に委ねる**。
「動くはず」という推測を検証済みとして書かない。

## issue分割の判定（flow-id 1-4）

**分割しない。** issue #70 は「同期スクリプト／`settings.json` 変換／`agents` 変換／リンク運用廃止／
ルール明文化／DDR」という複数の成果物を持つが、これらは**同時に変えないと壊れる横断的変更**である
（例: リンク運用を廃止しながら同期スクリプトが無いと、`.gemini/` 配下が単に消える）。
`.claude/skills/issue-mr-flow/SKILL.md`「分割しない条件」の**横断的変更**に該当する。

ただし次の2つは**切り出し候補**として保持し、フェーズ2の調査結果しだいで判断する。

1. **`skills/` の変換**（Gemini CLI が `SKILL.md` を読むかが未確認。読まないなら対象外にできる）
2. **新規 flow-id の採番**（下記「主要な論点」参照）

## 主要な論点（フェーズ2で決着させる）

| # | 論点 | 選択肢 |
|---|---|---|
| L1 | Gemini CLI の `agents` frontmatter スキーマ（`tools` の正しい語彙・`model` の扱い） | 一次情報を調べて確定する。不明なら**変換規則を設定表として外だしし、後から差し替え可能にする** |
| L2 | Gemini CLI が `skills/` を読むか | 読む→変換対象／読まない→コピーのみ or 対象外 |
| L3 | 同期の実行位置を**新規 flow-id** にするか、既存ステップへ統合するか | issueは「5-3の直前に新設」と書くが、**この番号は issue #111（統括レポート）以降ずれており、現在の片付けは 5-4**。繰り下げは13ファイル・数十箇所に波及する。代案は「片付け（現 5-4）の `cleanup-task.sh` へ統合」または「flow-idを増やさない並行手順として定義」（`REVIEW-POINTS.md` 収集・追従監視と同じ扱い） |
| L4 | `.gemini/` を Git 管理下に置くことの副作用 | `rg`/`grep` の二重ヒット・`index.jsonl` の二重生成・`extract-frontmatter.sh` の走査対象が倍増する。除外の要否を決める |
| L5 | 配布（`apply-mr-workflow-to-project`）への波及 | `sync-assets.sh` / `install-to-project.sh` / `distribution-assets.md` が `.gemini` に言及している。配布先で同期スクリプトをどう実行させるか |

## フェーズ2〈調査〉

**実施する。** 上記 L1〜L5 は、いずれも既知の情報だけでは個別作業計画（3-1）を書けない。

- 調査計画: `plans/【調査】gemini-cli記法と同期方式の確定.md`
- 調査内容
  1. Gemini CLI の agents/settings.json/skills のスキーマを一次情報から確定する（L1・L2）。
     **実機が無いため、出典URLを結果レポートへ必ず残す**
  2. `.gemini` / `setup-gemini-links.sh` の参照箇所を全件洗い出し、変更対象ファイルを確定する（L5）
  3. flow-id 繰り下げの実コストを実測する（L3）
  4. `.claude/` 配下のどれをコピー対象・除外対象にするかを決める（L4。`index.jsonl`・`state/` 等）
- 成果物: `reports/日付_nimble-syncing-lantern_gemini同期方式の調査.md` ＋ `.html`

## フェーズ3〈作業〉

調査結果をもとに確定するが、現時点の見込みは次のとおり。

- `plans/【設計】【実装】sync-gemini-assets.md`
  - `.claude/scripts/src/sync-gemini-assets.sh` の新設（`--check` モード・冪等・除外規則）
  - `settings.json` の写像（イベント名・matcher・`command`＋`args[]`→単一文字列・timeout秒→ミリ秒・
    `${CLAUDE_PROJECT_DIR}`→`${GEMINI_PROJECT_DIR}`・`plansDirectory`→`general.plan.directory`・
    `if` の畳み込み・`permissions` の破棄・`name` の生成）
  - `agents/*.md` の frontmatter 変換（`tools`・`model`）
- `plans/【テスト】sync-gemini-assets.md`
  - `.claude/scripts/test/test_sync_gemini_assets.sh`（純粋ロジックの単体テスト。
    `passed=N failures=N` 規約）
  - 冪等性の検証（2回実行して差分ゼロ）
- リンク運用の廃止（`setup-gemini-links.sh` の削除・`.gitignore` の該当行削除・
  **既存リンク／ジャンクションの撤去手順の文書化**）

## フェーズ4〈反映〉

**必ず通る。** 反映対象は flow-id 4-1 で洗い出すが、現時点で見込みがあるものを候補として挙げる
（確定した反映内容としては扱わない）。

- **設計反映**: `.claude/docs/spec/` に同期スクリプトの仕様を新設。
  `.claude/docs/spec/distribution-assets.md` の更新
- **DDR**: `i0000-13`（リンク運用）に `status: superseded` / `superseded_by` を付け、
  新DDR `i0070-01`（変換生成物方式への転換）を追加する。
  **`bash .claude/scripts/src/generate-ddr-list.sh` の再実行を同じコミットに含める**
- **AIアセット反映**: `AGENTS.md`・`.claude/rules/directory-structure.md` へ運用ルール
  （手で編集してよいのは `.claude/` のみ／検索が二重ヒットしたら `.claude/` 側を直す）を明文化。
  L3 の結論しだいで `.claude/skills/issue-mr-flow/SKILL.md` の全体フロー表も更新

## 検証方針

- `bash -n` による構文チェック（全 `.sh`）
- `.claude/scripts/test/` の単体テストを**全件**流し、`failures=0` を確認する
- 同期スクリプトの冪等性（2回目の実行で差分ゼロ）
- `--check` が差分ありのときに非0で終わること
- **各フェーズの結果確認時に敵対的レビュー**（`adversarial-review` スキル）を実施する
  （ユーザーからの明示指示による）

## やらないこと

- Gemini CLI の実機での動作確認（この環境に CLI が無いため）
- GitLab 側（`glab`）に関する変更
- issue #26（AIアセットのmanifest配布）本体の書き直し（本issueの結論を前提とする旨の記載に留める）
