---
title: worklog 20260823 humming-mapping-pie 【設計反映】OTelリスナー機構のDDR_spec新設 push1
type: log
description: issue #103のフェーズ4個別反映計画（設計反映）作成の試行錯誤ログ
tags: [otel, telemetry, usage, perl, worklog]
keywords: [OpenTelemetry, DDR, spec, 設計反映, i0103]
---

# worklog: 【設計反映】OTelリスナー機構のDDR_spec新設

対象: issue #103のフェーズ4（反映）着手（2026-08-23〜）。
全体作業計画: `plans/humming-mapping-pie.md`
個別反映計画: `plans/【設計反映】OTelリスナー機構のDDR_spec新設.md`
push回数: 1

## 試したこと

- フェーズ2調査結果・フェーズ3実装結果（`reports/`配下2件）を読み直し、恒久的に残すべき
  意思決定（DDR）と現在の仕様（spec）を洗い出した。
- `.claude/rules/docs-workflow.md`「【設計反映】と【AIアセット反映】は基本的に併記せず
  分ける」方針に従い、個別反映計画を2ファイルに分割した
  （`【設計反映】OTelリスナー機構のDDR_spec新設.md`と
  `【AIアセット反映】OTelリスナー機構のルール反映.md`）。

## うまくいったこと

- DDRを2件に分けた（perl採用理由／`.claude/settings.local.json`分離理由）。既存の
  対応工数レポート（DDR i0000-04）との関係整理は、独立した意思決定ではなく
  「並行経路である」という関係の明示なので、DDRではなくspec側の背景節に書く方針とした。

## ダメだったこと

（現時点では無し。計画作成段階のため実装上の失敗はまだ発生していない）

## 次の一歩

- 個別反映計画2件・worklog・HANDOFF.mdをcommit・pushしレビュー依頼を行う（flow-id 4-2）。

## flow-id 4-6: 設計反映の実施（このpush内で継続中）

### できたこと

- `.claude/docs/ddr/i0103-01-perlを常駐プロセス実装の選択肢に加える理由.md`・
  `.claude/docs/ddr/i0103-02-OTelエンドポイント設定をsettings.local.jsonへ分離する理由.md`を
  新規作成した。既存DDR（`i0141-01`）のfrontmatter・見出し構成を参考にした。
- `.claude/docs/spec/otel-listener.md`を新規作成した。既存spec（`cleanup-task.md`）の
  「背景・目的／仕様／影響範囲／未決定事項・懸念点」構成を踏襲した。
- `bash .claude/scripts/src/generate-ddr-list.sh`でDDR一覧を再生成（73件、2件追加のみの差分）。
- `.claude/docs/README.md`「spec（機能仕様）」節は生成物ではないため手動で1行追加した。
- `bash .claude/scripts/src/extract-frontmatter.sh`でDDR・specディレクトリのfrontmatter抽出を
  検証し、failed=0を確認した。
- 実装結果を`reports/20260823_humming-mapping-pie_OTelリスナー機構の設計反映.md`へ記録した。

### 次の一歩

- 設計反映分をcommit・pushしレビュー依頼を行う（flow-id 4-7、1周目）。
- レビュー完了後、AIアセット反映（`directory-structure.md`・`shell-script-style.md`）に着手する
  （flow-id 4-6、2周目）。

## flow-id 4-7〜/adversarial-review: commit・push・敵対的レビュー

### できたこと

- `create-commit.sh`経由でコミット`31d66e9`（DDR2件・spec1件・README.md・reports・worklog・
  HANDOFF.md）を作成し、リモートへ反映してレビュー依頼メッセージを送った。
- ユーザーから`/adversarial-review`が明示的に呼ばれたため実施した（対話セッションでのAI自律起動は
  禁止だが、今回は人間の明示呼び出し）。フェーズ4の実施回数は0→1（上限3回）。
- 対象は「設計反映」（DDR2件・spec1件）に絞った（`otel-listener.md`は本MRで唯一の変更ではあるが、
  `listener.pl`等の実装ファイルはフェーズ3で既にレビュー済みのため対象外とした）。
- `adversarial-reviewer`サブエージェントが17件のfindingsを返した。確度・重大度マトリクスで
  major×high/mediumの10件が投稿基準に達し、`add_mr_inline_comments`でMR #158へ投稿
  （`{"posted":10,"summarized":0}`）。

### 投稿した10件の要旨

1. WSL側リスナーの待受ポート（`OTEL_USAGE_PORT=4319`）を設定する経路がspec/テンプレート/導入手順の
   どこにも無い（結線不能になりうる）。
2. テスト配置の例外（`.claude/hooks/otel/test/`）をspec側だけで宣言しており、
   `directory-structure.md`/`index.md`が未追随（正が2つ）。
3. DDR i0103-01の出典参照が誤り（`shell-script-style.md`ではなく`shell-scripts.md`が正）。
4. 「常駐プロセスならperl」の枝を規範側（`shell-scripts.md`）へ追記していない。
5. 配布対象アセットが増えているのに`.claude/VERSION`が据え置き。
6. 配布先での既定動作（テレメトリ既定ON・毎セッション常駐perl起動）がspecに未記載。
7. 「既知の制限」の根拠がGit管理外の`参考ディレクトリ/otel/README.md`に丸投げ。
8. specから`reports/…md`（flow-id 5-4で削除される）を参照している。
9. 読み取りタイムアウト無しで1接続がacceptループを恒久停止させうる点が未記載。
10. DDR i0103-02本文から`reports/…md`を参照している（本文は後から直せない）。

### 報告のみに留めた7件

`HANDOFF.md`「敵対的レビューで報告のみに留めた指摘」節に記載（minor×high 4件・minor×medium 1件・
対象外ファイル`listener.pl`の参照切れ1件）。

### 次の一歩

- flow-id 4-8: 人間のレビュー待ち（MR投稿分10件・報告のみ7件を含めてレビュー依頼済み）。

---
