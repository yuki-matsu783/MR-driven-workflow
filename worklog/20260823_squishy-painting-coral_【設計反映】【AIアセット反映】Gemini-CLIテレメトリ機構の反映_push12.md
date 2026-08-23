---
title: 20260823 squishy-painting-coral 【設計反映】【AIアセット反映】Gemini-CLIテレメトリ機構の反映 push12
type: log
description: issue #105フェーズ4（反映）flow-id 4-1〜4-2の作業ログ。個別反映計画2本（設計反映・AIアセット反映）の作成経緯
tags: [gemini-cli, telemetry, worklog, issue-105]
keywords: [flow-id 4-1, 個別反映計画, spec, ddr, ai-asset]
---

# 20260823 squishy-painting-coral 【設計反映】【AIアセット反映】Gemini-CLIテレメトリ機構の反映 push12

## flow-id 4-1: 個別反映計画の作成

フェーズ3完了（flow-id 3-10までMR descriptionを最新化済み）を受け、反映対象を洗い出した。

### 反映対象の洗い出し

- **spec**: `otel-listener.md`と対をなす新規spec（Gemini CLI公式テレメトリ機構）が必要。
  既存の`sync-gemini-assets.md`にも、本issueで覆した結論（「Gemini CLI 経路では対応工数の
  OTel 計測が行われない」）が残っており、訂正が要る。
- **DDR**: フェーズ2・3の敵対的レビューで裏取りした判断のうち、却下案・トレードオフを伴う
  ものを記録する価値があると判断した。特に以下の2つ:
  - 二重計上回避方式（semantic conventions形式のみ採用しレガシー形式・metricsを除外する判断）。
    これは「両形式を採用し重複排除する」「レガシー形式のみ採用する」という具体的な却下案がある。
  - 既定有効化を保留した判断（配布先`.gitignore`未整備・機微情報未確認の2条件）。
    これも「配布先是正と同時に既定ONにする」という却下案がある。
  - カーソル方式の耐障害性（`prefixFingerprint`等）は、却下案を伴う意思決定というより
    実装の詳細（バグ修正）に近いと判断し、独立のDDRにはせず新規specの本文へ実装済みの事実として
    記述するに留めた。
- **実装コード・テストコード**: フェーズ3のレビュー往復ループ（3-6〜3-9）で全指摘に対応済み。
  持ち越した不具合は無いため、`【実装反映】`は不要と判断した。
- **AIアセット**: このセッション自身が、PR #174のレビュースレッド再取得（flow-id 3-9）で
  `mcp__github__pull_request_read`のページネーションパラメータを誤り（`cursor`ではなく`after`
  が正）、同じページが繰り返し返るハングを2回連続で起こした。次のセッションが同じ回り道を
  しないよう、`issue-mr-flow/SKILL.md`のMCPフォールバック節へ注記を追加する価値があると判断した。

### 計画ファイル

「フェーズごとに個別の合意・レビューを挟みたい場合は分ける」の基準（SKILL.md「種別を複数併記
する場合／分ける場合」）に従い、`【設計反映】`と`【AIアセット反映】`は評価軸が異なる
（正史ドキュメントへの記録 vs AIエージェント運用の改善）ため分けた。

- `plans/【設計反映】Gemini-CLIテレメトリ機構のspec・DDR記録.md`（＋同名html）
- `plans/【AIアセット反映】PR-review-commentsページネーションのSKILL反映.md`（＋同名html）

いずれもplanツールを使わずWrite/Editで作成した。HTMLビューは
`.claude/skills/issue-mr-flow/assets/plans.template.html`を土台に、`plans.template.html`の
`[全体作業計画のみ必須]`セクション（フェーズ2〈調査〉・フェーズ4〈反映〉）は個別計画のため
削除した。プレースホルダ残存が無いことを`grep -c '<!-- ここに書く'`で確認した（両ファイルとも0件）。
