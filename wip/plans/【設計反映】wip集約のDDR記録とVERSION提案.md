---
title: 個別反映計画 - wip集約のDDR記録とVERSION提案
type: plan
description: issue #165フェーズ4。wip/命名理由のDDR化・.claude/VERSION MAJOR増分の適用（非対話セッション例外）・既存導入先向け移行手順の記述先決定と記述の3点を反映する個別計画
tags: [issue-mr-flow, ddr, distribution-assets, wip]
keywords: [wip, ddr, VERSION, MAJOR, 移行手順, install-to-project, distribution-assets, cleanup-task, dist-layers]
---

# 個別反映計画: wip集約のDDR記録とVERSION提案（issue #165 フェーズ4）

## 前提（合意状況）

- 上位の計画: `wip/plans/transient-brewing-pelican.md`（flow-id 1-5 で合意）
- 依拠する実装結果: `wip/reports/20260823_transient-brewing-pelican_wip集約実装結果.md`
  「設計への反映（フェーズ4で対応）」節
- 関連DDR: `i0165-01`（フォールバック既定値の後方互換。本計画とは別論点）

## 対象

`.claude/docs/spec/cleanup-task.md`の未決定事項更新（実装結果レポートの項目2）は、mainマージ
解消の過程で既に`i0165-01`とあわせて対応済み（「解消・issue #165」と明記済み）。本計画は残る
3項目——DDR記録・VERSION対応・移行手順の記述——を扱う。フェーズ4の他種別（AIアセット反映・
実装反映）は「やらないこと」節で扱いを明記する。

## この計画で何をするか

1. **`wip/`という名前の採用理由をDDRとして記録する**（受け入れ条件7）。`flow/` `tasks/` `work/`
   `scratch/`を採らなかった理由を含む。
2. **`.claude/VERSION`を`MAJOR`（`0.3.0`→`1.0.0`）へ更新する。** 非対話的実行環境における例外
   規定（`.claude/docs/spec/distribution-assets.md`「増分の決め方」の「例外（非対話的セッション）」
   節。issue #160が先例）に従い、**AIエージェントが目安表に沿って適用**し、根拠と適用の事実を
   spec changelogと`HANDOFF.md`「判断を迷った内容」の両方へ残す。人間がレビューで否認した場合は
   元の`0.3.0`へ戻す。
3. **既存導入先向けの移行手順**を`.claude/docs/spec/asset-distribution.md`へ記述する。
   `i0165-01`「未決定事項」が本タスクへ委譲している論点。

## 変更対象

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/docs/ddr/`配下の新規DDR（識別子`i0165-02`） | 新規 | `wip/`命名の採用理由と却下案（flow/tasks/work/scratch）を記録。`i0165-01`の未決定事項（移行手順・VERSION）をここで引き取る旨を明記 |
| `i0165-01`（既存DDR。ファイル名は`.claude/docs/README.md`のDDR一覧参照） | frontmatterのみ更新 | `note:`キーで、移行手順・VERSION対応の解消先（`i0165-02`・`asset-distribution.md`）を1行で示す（DDR本文は不変。frontmatterのみの更新は許可されている） |
| `.claude/docs/README.md` | 生成物の更新 | DDR追加に伴い`bash .claude/scripts/src/generate-ddr-list.sh`で再生成し、同じコミットへ含める |
| `.claude/VERSION` | 変更 | `0.3.0` → `1.0.0`（非対話セッション例外の適用） |
| `.claude/docs/spec/distribution-assets.md` | 変更 | 「### `.claude/VERSION`」の直下（issueごとのchangelog節）へ issue #165 エントリを追加し、適用した増分・根拠・現在値との整合（下記「方針」参照）を記録 |
| `.claude/docs/spec/asset-distribution.md` | 変更 | 「## 移行」小節を新設（恒久の仕様として、改名時に配布先が取るべき一般手順）＋「## 影響範囲 > issue #165」エントリ（今回固有の`plans/`→`wip/plans/`等の具体的な移行手順）の2箇所に分けて追加 |

## 方針

### 1. DDR新規作成

識別子`i0165-02`（同一issue内で`i0165-01`の次の枝番）として、`.claude/docs/ddr/`配下へ
`.claude/rules/markdown-frontmatter.md`「DDRの識別子」規則に沿ったファイル名で新規作成する
（タイトル案: 「タスク単位ディレクトリの集約名はwip/を採用しflow/tasks/work/scratchを採らない」。
実装時に確定したファイル名は、下記「変更対象」表と本節を計画側で追随させる必要はない
——参照は識別子のみで行っているため）。理由（草案）:

- **`wip/`（Work In Progress）**: 「未完了・一時的で正史ではない」という寿命をそのまま表す、
  広く認知された慣用語。既存の`.claude/`語彙と衝突しない。
- `flow/`を採らない理由: 「フロー」という語は本リポジトリで一貫して手順そのもの
  （`.claude/skills/issue-mr-flow/SKILL.md`）を指すため、`flow/`ディレクトリは「フローの
  ドキュメント」ではなく「フローが生成する一時ファイル」と誤読される。
- `tasks/`を採らない理由: 汎用的すぎて「タスク管理（TODO・issue管理）」の含意と衝突しうる。
  「flow-id 5-5で削除される」という寿命の短さが名前から伝わらない。
- `work/`を採らない理由: 最も汎用的で、導入先プロジェクトが独自に持つ「作業用ディレクトリ」
  （ビルド成果物置き場等）と衝突しやすい。寿命の短さも名前から伝わらない。
- `scratch/`を採らない理由: 「使い捨てのメモ」という含意が強すぎる。`wip/plans/` `wip/reports/`は
  人間のレビューを経る正式な成果物であり、「使い捨て」ではなく「一時的だが正式」という性質と
  ズレる。

DDR本文の末尾に「`i0165-01`の未決定事項（移行手順・VERSION増分）はここで引き取り、移行手順は
`asset-distribution.md`「移行」小節へ、VERSION対応は`distribution-assets.md`のchangelogへ
それぞれ記述した」旨を1文添える。あわせて`i0165-01`のfrontmatterへ`note:`を追記し、
`.claude/docs/README.md`のDDR一覧からも解消先を辿れるようにする（`.claude/rules/markdown-frontmatter.md`
「DDRのnote」参照）。

**計画md内でのDDR参照は識別子（`i0165-02`）で書き、確定ファイル名を決め打ちしない。** 実装時に
タイトルの語順・表記が変わってもこの計画への参照切れが起きないようにするため。

### 2. `.claude/VERSION`のMAJOR適用

**現在値の確認**: `.claude/VERSION`は現在`0.3.0`である（issue #160が非対話セッション例外の
先例として`0.2.0`→`0.3.0`のMINOR適用を行った。`distribution-assets.md`「issue #170」エントリの
「`0.2.0`のまま据え置いた」という記述は、issue #170時点（issue #160マージ前）の事実であり、
現在の値とは異なる時系列上の記録として変更しない）。

**今回の判断**: `.claude/dist-layers.json`の配置場所変更（`plans`/`worklog`/`reports`のトップ
レベル→`wip/`配下への集約）は、`distribution-assets.md`のMAJOR目安「配布先に手作業を要求する
非互換変更（配置場所の変更…）」に直接該当する。SemVerの0.xからのMAJOR増分は`1.0.0`とする
（`distribution-assets.md`「issue #26」エントリでAIエージェントが同じく`1.0.0`を提案した先例に
倣う）。

**適用するか提案に留めるかの判断**: 過去2回（issue #54・issue #26）、AIが提案したMAJOR増分は
いずれも人間のレビューで**否認**され据え置かれている。一方issue #160はMINOR増分を**非対話
セッション例外**の下で実際に適用した最初の前例である。本タスクも非対話セッションであり、同じ
例外規定が適用できるため、**提案に留めず適用する**。ただし過去2回の否認実績を踏まえ、
`distribution-assets.md`のchangelogへ「MAJORを適用したが、過去2回はMAJOR提案が据え置かれている」
という判断の迷いも明記し、人間が容易に判断・差し戻しできるようにする。

### 3. 既存導入先向け移行手順

移行手順は「恒久の一般手順」（今後も同種の改名が起きうる、`asset-distribution.md`の仕様節）と
「今回固有の具体的手順」（`distribution-assets.md`の影響範囲changelog）に分けて書く。実際に
配布先で何が起きるかを本ツリーで確認したうえで、少なくとも次の4点を含める。

1. **`.claude/dist-layers.json`は`wip/plans` `wip/worklogs` `wip/reports`を`local`（配らない）
   層とする一方、`wip/plans/REVIEW-POINTS.md` / `wip/worklogs/TEMPLATE.md` /
   `wip/reports/REVIEW-POINTS.md`の3件を`core`として個別に持つ。** 配布先には**新パスにだけ**
   この3ファイルが置かれ、旧`plans/REVIEW-POINTS.md`等はそのまま残る（`asset-distribution.md`
   「インストーラの2パス構成」の『本家で削除・改名されたファイルは、配布先から削除しない』）。
2. **旧方式（manifestを持たない）で導入済みの配布先には「削除・改名されたcoreファイルの一覧」が
   提示されない。** `install-to-project.sh`の該当ロジックは前回のmanifestと突き合わせて動作する
   ため。
3. **配布先の`.mrworkflow.json`は`seed`層（配布先所有・上書きしない）**なので、`plansDir` /
   `worklogDir` / `reportsDir`は自動では変わらない。手動で`wip/plans` / `wip/worklogs` /
   `wip/reports`へ書き換える必要がある。
4. **`.claude/settings.json`の`plansDirectory`も配布先所有**（`merge`/`json-keys`層で
   `keys`は`hooks`と`permissions.deny`のみが対象）。これも手動で`./wip/plans`へ書き換える
   必要がある。

一般手順（仕様節）には「①`.mrworkflow.json`の3キーを新パスへ変更、②`.claude/settings.json`の
`plansDirectory`を変更、③既存の`plans/` `worklog/` `reports/`を`git mv`で`wip/`配下へ移動、
④次回`install-to-project.sh`実行時に新パスのcoreファイル3件が追加されることを確認」という
手順の型を書く。issue #165固有のchangelogエントリには、実際のパス名（`plans`→`wip/plans`等）と
具体例を書く。

## やらないこと（スコープ外）

- **フェーズ4の他種別（`【AIアセット反映】` `【実装反映】`）は実施しない。** 作業中に気づいた
  ルール・スキルの不備は無く（フェーズ3の敵対的レビュー指摘はすべて計画・実装へ反映済み）、
  フェーズ3のレビュー往復ループで解消しきれず持ち越した不具合も無いため、対象が無いと判断した。
- 既存導入先での移行手順の実行そのもの（各配布先の作業であり本タスクの対象外）
- `.claude/VERSION`のMAJOR適用が人間のレビューで否認された場合の巻き戻し作業（レビューで
  指摘された時点で対応する。本計画には含めない）

## 検証

**変更前の期待値（着手前に確認済み）**: `bash .claude/scripts/src/generate-ddr-list.sh --check`
は exit 0（84件）。`bash .claude/scripts/src/check-doc-references.sh`は**参照切れ1件
（本計画md内の未確定DDRファイル名）で exit 1**（実装後は識別子参照に直すため0件・exit 0になる
はず）。単体テストは全件`passed=N failures=0`（本計画の変更はドキュメントのみのため、退行が
無いことの確認に位置づける）。

```bash
# DDR一覧が新規DDRを含めて再生成され、--checkが通ること
bash .claude/scripts/src/generate-ddr-list.sh
bash .claude/scripts/src/generate-ddr-list.sh --check   # exit 0 を確認

# 新規DDRの識別子形式・重複が無いこと
bash .claude/scripts/src/check-base-conflicts.sh --no-fetch | jq '.hasDuplicateDdrNumber'  # false

# index.jsonlにi0165-02がtype:ddrで載ること
bash .claude/scripts/src/extract-frontmatter.sh .
grep '"i0165-02"' .claude/docs/spec/index.jsonl   # 1件ヒット（frontmatterインデックス内のtitle等から）

# DDR参照切れが無いこと（着手前は参照切れ1件、実装後は0件になることを確認）
bash .claude/scripts/src/check-doc-references.sh   # exit 0・参照切れ0件

# 単体テスト全件（退行が無いことの確認）
for t in .claude/scripts/test/test_*.sh; do bash "$t"; done   # 全件 passed=N failures=0
```

合格条件: 上記すべてのコマンドが記載の期待値どおりに終わること。
