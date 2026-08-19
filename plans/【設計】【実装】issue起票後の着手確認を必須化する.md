# 【設計】【実装】issue起票後の着手確認を必須化する

対象: issue #39「issue起票後にissue-mr-flowへ進む際は必ず人間の確認を挟む」

## 前提（調査で分かったこと）

- issue #59の対応で `issue-create/SKILL.md` には既に「ユーザーの明示的な指示なしに、同一セッションで
  `/issue-mr-flow start` へ進まない」が入っている。**issue #39の受け入れ条件1はほぼ満たされているが、
  「着手確認そのものを省略しない」という直接的な記載と、事故の実例が無い。**
- `issue-mr-flow/SKILL.md` の `start` 節・`AGENTS.md` には該当の記載が一切無く、そちらから読み始めた
  場合に方針へ辿り着けない（受け入れ条件2・3が未達）。
- 機構的な強制（受け入れ条件4）は未検討。既存のhookはコミット直接実行のブロック（PreToolUse）と、
  push検知の2種類（PostToolUse）。

## 方針

1. **ドキュメントを一次的な担保にする**（3ファイルのどこから読んでも同じ結論に辿り着く形にする）
   - `AGENTS.md`: 「issueを起票したこと自体は着手の指示ではない」を共通ルールへ追加
   - `issue-create/SKILL.md`: 「してはいけないこと」へ着手確認の省略禁止（issue #38の事故の実例つき）
   - `issue-mr-flow/SKILL.md`: `start` 節冒頭へ、起票直後の連続実行はユーザーの明示指示が前提である旨
2. **機構は「注意喚起の注入」に留める**（多重防御）
   - `.claude/hooks/post-issue-create-notice.sh`（PostToolUse hook）を新設し、起票を検知して
     `hookSpecificOutput.additionalContext` で注意を注入する
   - 検知はCLI経路（`create-issue.sh`）とMCP経路（`mcp__github__issue_write` の `method="create"`）の2つ
   - 判定は純粋関数へ切り出し、`.claude/scripts/test/` に単体テストを置く
3. **ブロック（PreToolUse + exit 2）は採用しない** → 理由と却下案をDDR 0034に記録する
4. spec（`issue-mr-workflow.md`）へ仕様と影響範囲を反映する

## 作業単位

- [x] hook本体と単体テストの実装
- [x] `.claude/settings.json` / `.gemini/settings.json` への登録
- [x] ドキュメント3ファイル（AGENTS.md・両SKILL.md）の更新
- [x] DDR 0034の作成と `.claude/docs/README.md` の一覧追記
- [x] spec への反映（コンポーネント構成・新節・影響範囲）

## 受け入れ条件との対応

| issue #39の受け入れ条件 | 対応 |
|---|---|
| issue-create SKILL.mdに着手確認必須が「してはいけないこと」を含めて明記 | 手順5の補強＋「してはいけないこと」へ1項目追加 |
| issue-mr-flow SKILL.mdのstartに起票直後の連続実行の前提を記載 | `start` 節冒頭に追加 |
| AGENTS.md等の共通ルールから辿れる | `AGENTS.md` のルールへ追加（両SKILL.md・DDRへの参照つき） |
| 機構的強制の可否を検討しDDRに記録 | DDR 0034（注意喚起を採用・ブロックは却下） |
