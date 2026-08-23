# worklog: 【設計】【実装】【テスト】Gemini CLIテレメトリ集計機構の実装

対象: issue #105 のフェーズ3個別作業計画作成（2026-08-23）。
全体作業計画: `plans/squishy-painting-coral.md`
個別作業計画: `plans/【設計】【実装】【テスト】Gemini-CLIテレメトリ集計機構の実装.md`
push回数: 8（予定）

## 試したこと

- flow-id 3-1着手前に、Explore（読み取り専用）サブエージェントをバックグラウンドで起動し、
  `.claude/hooks/lib/UsageTracking.sh`・`.claude/hooks/post-push-usage-report.sh`・
  `.claude/scripts/test/test_usage_tracking.sh`・`.gemini/settings.json`・
  `.claude/scripts/src/sync-gemini-assets.sh`・`.gitignore`・`.claude/docs/spec/otel-listener.md`・
  DDR i0097-01 を事前調査した。
- 調査の結果、**フェーズ2報告作成時点では想定していなかった重要な制約**を発見した:
  defaultブランチ追従で取り込んだPR #157（issue #70）により、`.gemini/`が`.claude/`からの
  変換生成物になっており、`.gemini/settings.json`を手編集する前提が崩れていた。
  `sync-gemini-assets.sh`の`convert_settings()`／`SETTINGS_JQ_FILTER`を変更対象に含めることで
  対応した。
- `UsageTracking.sh`の既存パターン（`_usage_read_gemini_totals`の自己回復ロジック、
  `epoch_from_iso8601`のstrptime非依存実装、`sync_usage_state`のengine分岐構造）を踏襲する形で、
  新規のバイトオフセットカーソル集計関数群を設計した。

## うまくいったこと

- 既存のGemini経路（セッションログ集計）と完全に独立した新規関数群として設計することで、
  受け入れ条件4（Claude Code側・既存Gemini経路の集計結果が変化しない）を設計レベルで保証できた。
- `install-to-project.sh`の配布gitignore追記漏れ（フェーズ2報告7.節で指摘済み）を、本計画の
  変更対象へ明示的に含めた。

## ダメだったこと

- 事前調査の途中で誤ってAgentツール（isolation: worktree）を意図せず起動してしまい、
  `.claude/worktrees/`ディレクトリが未追跡のまま残った（stop hookが検知）。エージェント完了後に
  `git worktree remove --force`で削除して対処した。以後、既存エージェントの状態確認は
  `ListAgents`を使う（Agentツールの新規起動を誤って行わない）。

## 次の一歩

- flow-id 3-2: `commit`スキル経由でcommitし、pushしてレビュー依頼を行う。
- push後、フェーズ3の敵対的レビューを1回実施する（計画時、ユーザー指示）。

## 追記（敵対的レビュー1回目・push8後、計画の修正）

flow-id 3-2の後、フェーズ3の計画時敵対的レビューを1回実施した（フェーズ3カウンタ=1）。
対象は `plans/【設計】【実装】【テスト】Gemini-CLIテレメトリ集計機構の実装.md`（＋同名html）。
20件の指摘（major多数・minor若干）のうち10件をMR #174へインラインコメント投稿し、残り10件は
レビュー本文へ報告のみとして記載した。**投稿・報告した20件すべてに対応し、計画（md・html）を
修正した。**

主な修正内容:

- **enabled値の自己矛盾**（コードブロックが`true`、直後の箇条書きが`false`）: `enabled: false`
  固定へ統一し、「利用者が手動でtrueにする」という運用記述を削除した。`.gemini/settings.json`は
  生成物であり手編集が次回生成で失われるため、この運用は成立しない。有効化手段の確立自体は
  未決定事項・スコープ外へ回した。
- **変更対象の欠落3件**: `.gemini/settings.json`（生成物の再生成・コミット）、
  `test_sync_gemini_assets.sh`（T9ゴールデンフィクスチャの更新）、
  `test_install_to_project.sh`（配布gitignoreの実際の反映確認）を変更対象表へ追加した。
- **既存テストを壊す設計ミス**: `build_usage_report_body`への引数追加が、既存5引数呼び出しを
  `set -u`配下で壊すことが判明。新引数は`"${6:-}"`のように既定値付きで受ける方針へ修正した。
- **バイト位置検出方法の欠落**: 「完全パースできた末尾バイト位置」の求め方が未記載だったため、
  pretty-print出力の列0の`}`+改行をエントリ境界とする具体的な方式を明記し、実装依存のリスクも
  記載した。
- **境界をまたぐ二重計上バグ**: レガシー形式・semantic形式の2エントリが別々の読み取り窓に
  分かれると二重計上されうる問題を発見。semantic conventions形式のみを採用しレガシー形式を
  無視する方式を既定化することで原理的に解消した。
- **engine分岐の設計不整合**: `post-push-usage-report.sh`の既存設計判断（列構成はengineではなく
  データで決める）と矛盾する`engine=="gemini"`分岐を、`outfile`存在有無によるデータ側の判定へ
  修正した。
- **検証手順のトートロジー2件**: `--check`検証（生成後にしか確認していなかった）と
  `git diff --stat`（引数なしで基点が不定）を、生成前の失敗確認・ブランチ分岐点基準の差分確認へ
  修正した。
- **install-to-project.shの現状記述の事実誤り**: `ignore_rules`が実際は3要素（うち1つは旧パスでは
  なく現行の配布行）であることを確認し、記述を訂正した。
- **人間への実機確認依頼の欠落**: 調査結果1.節の7項目をこの計画へ転記し、依頼するflow-id
  （3-3または3-6後）と、データが得られない場合の代替方針（semantic形式のみ採用を確定値として
  進める）を明記した。
- その他minor: カーソル状態ファイルのパス衝突回避（サブディレクトリ化）、初回カーソル0での
  全量計上の明示化とテストケース追加、推測ベースフィクスチャの但し書き追加、
  `SETTINGS_IGNORED_KEYS`の`env`コメント更新の追記、md/html非同期の解消（HTML全面更新）。

---
