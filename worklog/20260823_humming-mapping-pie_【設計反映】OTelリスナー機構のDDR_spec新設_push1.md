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

## flow-id 4-9相当: 敵対的レビュー指摘（投稿10件・報告7件）への対応

### できたこと

ユーザーから「OK.修正して。他プロジェクトに配布することも考えると、issue番号もあまり参照
すべきではなく、内容を要約して記載すること」という指示を受け、投稿済み10件・報告のみ7件の
計17件すべてに対応した。

- **投稿10件**: WSL側`OTEL_USAGE_PORT`の設定経路を`.claude/settings.local.json.example`・
  spec・`DEVELOPERS.md`の3箇所へ追加、テスト配置ルールを`directory-structure.md`・`index.md`へ
  追記（specは参照するだけに変更）、DDR i0103-01の出典参照を`shell-scripts.md`へ訂正、
  同ファイルへ「常駐プロセスならperl」の枝を追記、`.claude/VERSION`を0.1.2→0.2.0へ更新、
  spec「配布時の扱い」節を新設（テレメトリ既定ON・常駐起動の明記）、既知の制限を自己完結化
  （`参考ディレクトリ`丸投げをやめる）、`reports/`参照を2箇所とも本文へ書き写して削除、
  読み取りタイムアウト無しの制限を追記した。
- **報告のみ7件**: session.id振り分けロジックの記述精度（1件でも解決すれば複製書き込み、
  全滅時のみunrouted）、デタッチ起動の分岐条件（`uname`ではなく`command -v setsid`）、
  対応表切り詰めの副作用、`DEVELOPERS.md`との既知の制限重複、DDR2件のコードスパン行またぎ
  （3箇所追加で発見）、`OTEL_METRICS_INCLUDE_SESSION_ID`のログ側根拠の弱さを修正した。
  `listener.pl`等の実装ファイルのコメントが`plans/`/`reports/`を参照する件は、今回の
  設計反映（DDR/spec）の対象外ファイルのため未対応のまま残す。
- **issue番号参照の削減**: ユーザー指示を受け、DDR2件・spec1件の本文から「issue #103」という
  形の参照をすべて除去し、issueの受け入れ条件・現状セクションへの言及を内容の直接要約に
  置き換えた（例:「issue期待する動作5は…を求めている」→「本機構は…という制約から環境ごとに
  別ポートを割り当てる必要がある」）。`.claude/docs/spec/`・`.claude/docs/ddr/`は配布対象アセット
  （`sync-assets.sh`が`.claude/*`を丸ごとコピー）であり、配布先では"issue #103"がこのリポジトリの
  issueを指さなくなるため。**ただしDDRのファイル名・タイトル・冒頭の識別子（`i0103-01`等）は
  `markdown-frontmatter.md`が定める命名規則上必須のため変更していない**。また
  `影響範囲`節の`### issue #NN（…）`という見出し形式は、本リポジトリの`spec`文書全体で使われている
  既存の changelog 慣習（例: `distribution-assets.md`）であり、恒久的に参照してよいという
  `docs-workflow.md`のルールとも整合するため、今回はこの慣習部分には手を入れていない
  （変更したのは`otel-listener.md`の`## 影響範囲`の小見出しから issue 番号を落とした点のみ）。
  この判断が意図と異なる場合は指摘してほしい。

### 検証結果

- `bash .claude/scripts/src/extract-frontmatter.sh .`: `failed=0`（frontmatter構文異常なし）。
- コードスパンの行またぎ（`` ` ``の奇数個/行を機械的に検出）: 修正対象ファイル一式で再走査し、
  フェンスコードブロック区切り以外の該当なしを確認。
- `jq -e .`で`.claude/settings.local.json.example`のJSON構文を確認。
- `.claude/VERSION`の末尾改行を旧ファイルとバイト単位で比較し維持されていることを確認。

### 次の一歩

- 上記対応をcommit・pushし、レビュー依頼を行う（flow-id 4-7、2周目相当）。

---
