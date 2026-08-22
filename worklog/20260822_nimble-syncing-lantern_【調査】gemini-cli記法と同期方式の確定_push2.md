---
title: worklog 【調査】gemini-cli記法と同期方式の確定
type: log
description: issue #70 の調査フェーズの試行錯誤ログ
tags: [worklog, gemini, 調査]
keywords: [gemini, agents, tools, settings.json, 同期, flow-id, 調査, 波及範囲]
---

# worklog: 【調査】gemini-cli記法と同期方式の確定

対象: .gemini/を.claude/からの変換生成物へ改める（issue #70）の調査（2026-08-22）。
全体作業計画: `plans/nimble-syncing-lantern.md`
個別作業計画: `plans/【調査】gemini-cli記法と同期方式の確定.md`
push回数: 2

## 試したこと

- flow-id 1-2: issue #70 をMCP経路（`mcp__github__issue_read`）で取得。**本文が途中で切れていた**ため、`method="get_comments"` でコメント2件も取得したところ、2件目（2026-08-20）が実質のissue本文（方針転換）だった
- flow-id 1-3: `check-base-sync.sh` で ahead=0/behind=0 を確認。Draft PR作成にはbaseとの差分が要るため `add_empty_commit_for_draft_mr` を実行
- flow-id 2-1: 調査計画を作成。Gemini CLI がこの環境に無いことを `command -v gemini` で確認済み
- flow-id 2-6: Gemini CLI の記法を調べるにあたり、WebSearch → 公式ドキュメント(WebFetch) → **リポジトリのソースコード**の順に情報源を上げた
  - `geminicli.com` は egress proxy に**ブロックされた**（`EGRESS_BLOCKED`）
  - `raw.githubusercontent.com` 経由の docs 取得は一部404（パスが違った）
  - 最終的に `add_repo` + shallow clone + sparse-checkout で `google-gemini/gemini-cli` を取得し、**バリデーション実装そのもの**を読んだ（コミット `5411f113`）
- `.claude/agents/issue-mr-resume.md` の frontmatter を python の `yaml.safe_load` で**実際にパースして型を測った**（`tools` が list ではなく str であることの確認）
- `flow-id 5-[3-6]` の出現箇所を `grep -rno` で実測（94箇所／DDR除く）。接頭辞無しの裸参照も含めると217箇所

## うまくいったこと

- MCP経路（`get_vcs_access_mode` → `mcp`）でのissue取得・PR作成がいずれも成功した
- **ソースコードを一次情報にしたことで、公式ドキュメントに書かれていない事実を3件つかめた**
  1. `localAgentSchema` が `.strict()` である（未知キーを拒否する）→ `title`/`type`/`tags`/`keywords` も変換対象
  2. skills のローダは `name`/`description` しか見ない寛容な実装 → **skills は変換不要**
  3. ツール名定数の実値（`Bash` → `run_shell_command` 等9種）
- 現行の手書き `.gemini/settings.json` が**10項目すべて正しい**と確認でき、ゴールデンファイルとして使える見通しが立った

## ダメだったこと

- `geminicli.com`（公式ドキュメントサイト）へのWebFetchは egress proxy にブロックされて使えなかった
- `raw.githubusercontent.com/.../docs/tools/index.md` `docs/get-started/configuration.md` はいずれも404。**docsのパス構成を推測で叩いたのが誤り**で、cloneしてから `ls docs/` で確かめるべきだった

## 次の一歩

- flow-id 2-7（commit・push）と敵対的レビュー
- フェーズ3では Q5（flow-id の採番。案C推奨）の合意を人間から取る

---
