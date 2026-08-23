---
title: 【設計】【実装】【テスト】wip集約とworklogs改名
type: plan
description: issue #165フェーズ3。plans/worklog/reportsをwip/plans, wip/worklogs, wip/reportsへ集約し、設定・スクリプト・ドキュメントの参照を更新する実装計画
tags: [issue-mr-flow, directory-structure, migration]
keywords: [wip, plans, worklog, worklogs, reports, git mv, cleanup-task, install-to-project, KEEP_PATHS]
---

# 【設計】【実装】【テスト】wip集約とworklogs改名

## 前提（合意状況）

- 全体作業計画: `plans/transient-brewing-pelican.md`（flow-id 1-5でユーザー承認済み）
- フェーズ2調査結果: `reports/20260823_transient-brewing-pelican_plansDirectoryネストパス検証.md`
  （`.claude/settings.json`の`plansDirectory: "./wip/plans"`は実際に機能することを実機確認済み。
  対照実験はインフラ一時停止のため保留中で、結果が出次第この計画・DDRへ反映する）
- **この確認は限定条件付きである**（報告書「確かめられなかったこと」節）。以下2点は未検証のまま
  この計画を進める。
  1. **N=1・Claude Code on the web（Linux）・2026-08-23限定**。ローカル環境（Windows/git bash）・
     別バージョンでの挙動は未確認。
  2. **`wip/plans`が事前に存在しない状態での挙動は未検証**（検証時点で`wip/plans/.gitkeep`が
     既に存在していた）。本リポジトリでは`git mv`でディレクトリごと作られるため直接の影響は無いが、
     `install-to-project.sh`で新規導入した配布先で`cleanup-task.sh`が`wip/plans`を空判定で削除した
     後（下記「方針3」の`.gitkeep`の論点参照）に同じ条件が成立しうる。
- `.gemini/settings.json`の`general.plan.directory`は、Gemini CLI自体が本実行環境に無いため
  **実行による確認ができていない**。本計画では`.claude/settings.json`と同じ変更を記法上の妥当性
  だけを根拠に適用し、実機未確認である旨をフェーズ4のDDRへ明記する（全体作業計画58-60行目の
  条件に対応）。

## この計画で何をするか

`plans/` `worklog/` `reports/` を `wip/plans` `wip/worklogs` `wip/reports` へ移動し、
それを参照する設定・スクリプト・ドキュメントをすべて新パスへ更新する。

## 変更対象

| 領域 | 操作 | 何をするか |
|---|---|---|
| `.mrworkflow.json` | 変更 | `plansDir: "wip/plans"`, `worklogDir: "wip/worklogs"`, `reportsDir: "wip/reports"` |
| `.claude/scripts/src/vcs/Provider.sh` | **変更しない** | `get_workflow_config`のフォールバック既定値（65-67行目、`plans`/`worklog`/`reports`）は据え置く（下記「方針1」末尾の理由参照） |
| `.claude/scripts/src/cleanup-task.sh` | 変更 | `KEEP_PATHS`のハードコード除去（設定値から動的に組み立てる）。**224行目のjqフォールバック既定値は変更しない**（Provider.shと同じ理由） |
| `.claude/settings.json` | 変更 | `plansDirectory: "./wip/plans"` |
| `.gemini/settings.json` | 変更 | `general.plan.directory: "./wip/plans"`（実機未検証。前提節参照） |
| `.claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh` | 変更 | `mkdir -p`対象（162-163行目）・`.gitkeep`配置（187-188行目）を`wip/`1つ＋配下3構成へ |
| `plans/` `worklog/` `reports/` 実体（`wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md` `wip/worklogs/TEMPLATE.md`を含む） | 移動（git mv） | `wip/plans` `wip/worklogs` `wip/reports` へ |
| ドキュメント参照（正確な件数は方針4の棚卸しコマンドで都度取得する。目安は下記「方針4」参照） | 変更 | 現在の状態を説明する箇所のみ新パスへ。移動した3ディレクトリ自身の恒久ファイル（上記REVIEW-POINTS.md/TEMPLATE.md）本文中の旧パス参照も対象に含める |
| `.claude/scripts/test/`配下の該当テスト（`test_cleanup_task.sh`を含む） | 変更 | 新パス前提での動作確認・必要な修正（`test_cleanup_task.sh`の修正内容は下記「方針1」） |
| `.claude/docs/spec/cleanup-task.md` | フェーズ4へ送る（本計画では変更しない） | 「未決定事項」節（194-197行目）の「KEEP_PATHSは`.mrworkflow.json`からは読まない」が本タスクで事実と食い違う。詳細は下記「方針1」末尾 |

`.claude/VERSION`は本計画の変更対象に含めない（「やらないこと」参照。MAJORインクリメントの提案自体もフェーズ4で行う）。

## 方針

### 1. KEEP_PATHSの動的化（最優先で対処する既知の欠陥）

`cleanup-task.sh`の`KEEP_PATHS=("worklog/TEMPLATE.md")`はハードコードされたリテラルパスであり、
`worklogDir`を`wip/worklogs`に変えると実際のファイルパス`wip/worklogs/TEMPLATE.md`と一致しなくなり
`TEMPLATE.md`が誤削除される。

**既存の記述を置き換える場合の置換前後（コード上の対応箇所）**

置換前（50-52行目）:
```bash
readonly -a KEEP_PATHS=(
  "worklog/TEMPLATE.md"
)
```

置換後（**`readonly`を外し、空配列で初期化する。`declare`は使わない**——`main`関数内で
`declare -a KEEP_PATHS=(...)`と書くとbashの仕様でその関数のローカル変数になり、以降の
`is_keep_path`呼び出し経路（`main`→`collect_files_under`→`is_keep_path`）では動的スコープにより
たまたま見えるが、`test_cleanup_task.sh`が`main`を経由せず直接`is_keep_path`を呼ぶ経路（下記）
では未設定のまま扱われ壊れる。素の代入文はグローバル変数への代入になるため、`main`内で単に
`KEEP_PATHS=(...)`と書く）:
```bash
# トップレベル（50-52行目）を次に置き換える。既存のコメント（なぜ worklog/TEMPLATE.md を
# 残すのかの根拠）はそのまま残す（値だけを空配列にする）。
KEEP_PATHS=()

# main() 内、dirs_tsv → target_dirs 読み込み（219-228行目付近）の直後に追加する。
# target_dirs[1] は worklogDir（224行目のjq配列 [plansDir, worklogDir, reportsDir] の並び順に
# 対応する。並びを変える場合はここも合わせて直すこと）。
KEEP_PATHS=("${target_dirs[1]}/TEMPLATE.md")
```

**`test_cleanup_task.sh`側の修正が必須**（これが無いと受け入れ条件2が満たせない）。同スクリプトは
`cleanup-task.sh`を`source`するだけで`main`を呼ばず、64行目以降で`is_keep_path`を直接呼んで
いるため、上記の変更後は`KEEP_PATHS`が空配列のまま評価され「is_keep_path: worklog/TEMPLATE.md は
残す」のテストが必ず失敗する。**`is_keep_path`の直接呼び出しの直前に、旧既定値を明示的にセット
する行を追加する**:
```bash
# is_keep_path は main() 内で初めて KEEP_PATHS を組み立てる設計になったため、
# main を経由しないこの単体テストでは呼び出し前に明示的にセットする
KEEP_PATHS=("worklog/TEMPLATE.md")
```
これにより既存の`is_keep_path`関連アサーション（`worklog/TEMPLATE.md`は残す・
`plans/REVIEW-POINTS.md`は残す等）は変更せずそのまま使える。`is_safe_relative_dir`側は
`KEEP_PATHS`と無関係のため変更不要。

**加えて、`main`経由の配線（dirs_tsvからKEEP_PATHSまで）自体を検証する結合テストケースを
新設する**（既存の結合テスト節、`.mrworkflow.json`無しの`setup_ct_repo`フィクスチャとは別に）。
`.mrworkflow.json`で`worklogDir: "wip/worklogs"`を指定したフィクスチャを作り、
`bash cleanup-task.sh --dry-run`の出力（`keptPaths`）に`wip/worklogs/TEMPLATE.md`が含まれる
ことを確認する。既存フィクスチャは`.mrworkflow.json`を持たないため常にフォールバック既定値
（`plans`/`worklog`/`reports`）で走り、この配線を一度も通らない（下記「方針5」のテスト項目に
反映）。

**`Provider.sh`・`cleanup-task.sh:224`のjqフォールバック既定値は変更しない。** 理由:
`.mrworkflow.json`を持たない配布先（本タスクの変更を未適用の既存導入先）は、まだ旧レイアウト
（`plans`/`worklog`/`reports`）のままである。フォールバックを`wip/*`へ変えると、そうした配布先で
`cleanup-task.sh`が存在しない`wip/plans`等を対象と誤認し、実際の`plans/`等が片付け対象から漏れる。
既定値は「`.mrworkflow.json`が無い＝旧レイアウトのまま」という前提を保つために据え置く。
本リポジトリ自身は`.mrworkflow.json`で明示的に`wip/*`を指定するため、フォールバックの値には
依存しない。

この決定により`.claude/docs/spec/cleanup-task.md`の「未決定事項」節（194-197行目）
「残すものの一覧は…`.mrworkflow.json`からは読まない」が、少なくとも`worklog/TEMPLATE.md`側に
ついては事実と食い違うことになる（単なるパス文字列の置換ではなく挙動の変更のため）。**本計画では
このspec自体は変更せず、フェーズ4（設計反映）で明示的に更新する**（同ファイル61行目の表・
124行目の`keptPaths`例・frontmatterの`description`/`keywords`も合わせて見直す）。

### 2. ディレクトリ移動

**チェックと`git mv`を同じ条件式で繋ぎ、チェックが偽なら`git mv`が走らないようにする**
（Bashツールへ渡す1回きりのコマンド文字列には`set -e`が無いため、別々の行に分けて書くと
チェックが偽でも後続の`git mv`がそのまま実行されてしまう。1周目レビュー・全体作業計画で
指摘済みの「移動先が既存ディレクトリだと二重ネストが無言で発生する」懸念に対する実効的な
ガードにするため）。

```bash
mkdir -p wip
if [ ! -e wip/plans ] && [ ! -e wip/worklogs ] && [ ! -e wip/reports ]; then
  git mv plans wip/plans && git mv worklog wip/worklogs && git mv reports wip/reports
else
  echo 'error: 移動先が既に存在します（wip/plans, wip/worklogs, wip/reports のいずれか）' >&2
fi
```

移動後、`wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md`
`wip/worklogs/TEMPLATE.md`が存在することを確認する（下記「検証」節に手順を含める）。

### 3. 設定・スクリプトの変更

上記「変更対象」表のとおり。`install-to-project.sh`は162-163行目の`mkdir -p`を
`mkdir -p "${DEST_DIR}/wip/plans" "${DEST_DIR}/wip/worklogs" "${DEST_DIR}/wip/reports"`へ、
187-188行目の`.gitkeep`を`wip/plans/.gitkeep` `wip/worklogs/.gitkeep` `wip/reports/.gitkeep`へ
変更する（`reports`にも`.gitkeep`を新設。現状reportsは作られていないため受け入れ条件4を満たす）。

**検討事項（現状維持と判断）**: `.gitkeep`は`cleanup-task.sh`の`KEEP_PATHS`/`KEEP_BASENAMES`の
いずれにも該当しないため、配布先で最初にflow-id 5-4を回した時点で`collect_files_under`が
`kept=0`と判定し、`wip/plans`等をディレクトリごと削除する（`REVIEW-POINTS.md`/`TEMPLATE.md`は
`sync-assets.sh`がリポジトリルートの`plans/`等をassetsへ集めていないため配布先に存在しない）。
**これは`wip/`集約前から存在した既存動作**（`plans/` `worklog/`についても同様に、配布直後は
`REVIEW-POINTS.md`/`TEMPLATE.md`を持たず`.gitkeep`だけで、初回flow-id 5-4でディレクトリが消えて
いた）であり、本タスク（ディレクトリの集約・改名）が新たに持ち込む問題ではないため、**本計画の
スコープでは対処せず現状維持とする**。恒久的な対処（`KEEP_BASENAMES`へ`.gitkeep`を追加する等）は
別issueとして切り出すことを検討し、その旨を最終統括レポート（flow-id 5-3）に記録する。

### 4. ドキュメント更新

対象は次のコマンドの結果を起点にする（**拡張子を絞らず、`plans`/`worklog`/`reports`のいずれも
スラッシュ無しで拾う**。当初案`'plans/\|worklog\|reports/'`は`plans`/`reports`側にだけスラッシュを
要求しており非対称で、`"./plans"`・`plansDir`・`reportsDir`のような表記を取りこぼす。棚卸しは
超集合にしておき、対象外かどうかは目視で判断する）。

```bash
git grep -lI -e plans -e worklog -e reports
```

（正確な件数はフェーズ3実施直前に上記コマンドで実測する。フェーズ2時点の見積り「約58/44/39」・
全体作業計画の見積りは、数え方の前提が揃わず本ブランチ上で再現しなかったため参考値に留める）

| 対象 | 扱い |
|---|---|
| `.claude/docs/ddr/*.md` | **本文は変更しない**（不変。frontmatterの`status`等のみ更新可能） |
| `.claude/docs/spec/*.md` | 節単位で判断。「現在の状態を説明する節」は更新、「point-in-time changelog節」（過去issueごとの影響範囲・変更履歴として書かれた節）は変更しない。`.claude/docs/spec/cleanup-task.md`の「未決定事項」節は本計画では変更せずフェーズ4へ送る（上記「方針1」末尾） |
| `.claude/hooks/otel/`配下の`.pl`/`.pm`（`listener.pl`・`lib/HttpMinimal.pm`・`test/test_otel_registry.pl`。コメント中に`plans/`・`reports/`のファイル名を参照している） | 対象に含める。`.claude/rules/docs-workflow.md`「コード・スクリプト内のコメントから`plans/` `worklog/` `reports/`のファイルを参照しない」に既に反する記述のため、参照先をissue番号または`.claude/docs/`配下のパスへ書き換える |
| `wip/plans/REVIEW-POINTS.md` `wip/reports/REVIEW-POINTS.md` `wip/worklogs/TEMPLATE.md`（移動後の実体。squash mergeでmainへ残る恒久ファイル） | 本文中の旧パス参照（`plans/【*.md`のパターン説明・`worklog/日付_…push<N>.md`の例・`reports/REVIEW-POINTS.md`への相互参照等）を新パスへ更新する |
| それ以外（`.claude/rules/`, `.claude/skills/*/SKILL.md`・`assets/`, `.claude/scripts/`, `.claude/hooks/`（`.sh`）, `.claude/agents/`, ルート直下, `.github/`, `.gitlab/`） | 現在の状態を説明する記述として、新パスへ更新する |

一括`sed`は使わない。ファイルごとに内容を確認しながらEdit/Writeで更新する。
`.claude/rules/directory-structure.md`のツリー構造・`index.md`（Repository Map）も対象に含める
（受け入れ条件8）。

**`cleanup-task.sh`編集時の注意**: `usage()`（190-192行目）は`sed -n '2,42p' "${BASH_SOURCE[0]}"`で
ヘッダコメント（2-42行目）をそのまま`--help`出力にしている。同じ範囲に今回書き換える記述
（8-10行目のディレクトリ名・27-30行目のJSON例）が含まれるため、**行数を変えずに書き換えるか、
変えるなら`usage()`の範囲（`2,42p`）も合わせて直す**。編集後`bash .claude/scripts/src/cleanup-task.sh --help`
の出力末尾が説明文で終わっていることを目視確認する（下記「検証」節に反映）。

### 5. テスト

少なくとも以下を実行し、`passed=N failures=0`を確認する。`test_cleanup_task.sh`は上記「方針1」の
2箇所の修正（既存の`is_keep_path`直接呼び出し前への`KEEP_PATHS`明示セット、`.mrworkflow.json`で
`worklogDir: "wip/worklogs"`を指定するフィクスチャを使った新規結合テストケースの追加）を含む。

```
bash .claude/scripts/test/test_cleanup_task.sh
bash .claude/scripts/test/test_search_frontmatter.sh
bash .claude/scripts/test/test_vcs_provider.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/test/test_check_base_sync.sh
bash .claude/scripts/test/test_collect_review_points.sh
bash .claude/scripts/test/test_extract_frontmatter.sh
bash .claude/scripts/test/test_session_start.sh
```

変更した`.sh`全てに`bash -n`で構文チェックを行う。

## やらないこと（スコープ外）

- DDR本文の書き換え（不変）
- `.claude/docs/spec/`内のpoint-in-time changelog節の書き換え
- `.claude/docs/spec/cleanup-task.md`の「未決定事項」節の更新（上記「方針1」末尾のとおりフェーズ4へ送る）
- `.claude/skills/apply-mr-workflow-to-project/assets/`への直接編集（生成物。`sync-assets.sh`が
  `.claude`/`.gemini`から再生成する）
- 既に`apply-mr-workflow-to-project`で導入済みの他プロジェクトの実際の移行作業
- `.claude/VERSION`の変更（提案自体もフェーズ4で行う。確定は人間の判断）
- `.gitkeep`が`cleanup-task.sh`に削除される既存動作への対処（上記「方針3」の検討事項参照。別issue化を検討）
- `Provider.sh`・`cleanup-task.sh:224`のjqフォールバック既定値の変更（上記「方針1」末尾の理由により据え置く）

## 検証

```bash
bash .claude/scripts/test/test_cleanup_task.sh
bash .claude/scripts/test/test_search_frontmatter.sh
bash .claude/scripts/test/test_vcs_provider.sh
bash .claude/scripts/test/test_install_to_project.sh
bash .claude/scripts/test/test_check_base_sync.sh
bash .claude/scripts/test/test_collect_review_points.sh
bash .claude/scripts/test/test_extract_frontmatter.sh
bash .claude/scripts/test/test_session_start.sh

# 移動後の実在確認（方針2手順3）
[ -f wip/plans/REVIEW-POINTS.md ] && [ -f wip/reports/REVIEW-POINTS.md ] && [ -f wip/worklogs/TEMPLATE.md ]

# KEEP_PATHSの動的配線が実際に機能していることを実リポジトリで直接確認する（方針1。
# --dry-run なので破壊しない）
bash .claude/scripts/src/cleanup-task.sh --dry-run | jq -e '.keptPaths | index("wip/worklogs/TEMPLATE.md")'

# cleanup-task.sh --help の出力末尾が説明文で終わっていること（usage()の行番号依存。方針4）を目視確認
bash .claude/scripts/src/cleanup-task.sh --help

# DDR本文・spec changelogを書き換えていないことの検証は、分岐点SHAを基準に固定して行う
git diff $(git merge-base main HEAD) -- .claude/docs/ddr/    # 空であること
git diff $(git merge-base main HEAD) -- .claude/docs/spec/   # 差分が「現在の状態を説明する節」のみに限られることを目視確認する
```

合格条件: 上記すべてのテストが`passed=N failures=0`。`wip/plans` `wip/worklogs` `wip/reports`が
実在し`REVIEW-POINTS.md`・`TEMPLATE.md`を含む。`git mv`による移動なのでファイル履歴が
`git log --follow`で追える。DDR本文への意図しない書き換えが無く、spec側の差分が現在の状態を
説明する節のみに限られる（`## 影響範囲`等のchangelog小節配下に変更行が無い）。

## issueの受け入れ条件との対応

| 受け入れ条件 | この計画での対応箇所 |
|---|---|
| 1. plansDirectoryのネストパス対応の実機検証 | フェーズ2で完了（本計画の前提） |
| 2. test_cleanup_task.shが新パスで通る | 方針1・5 |
| 3. test_search_frontmatter.sh / test_vcs_provider.shが通る | 方針5 |
| 4. install-to-project.shがwip/1つ＋配下3構成を作る | 方針3 |
| 5. DDR本文・spec changelogを書き換えない | 方針4 |
| 6. git mvで移動する | 方針2 |
| 7. wip/命名判断をDDRとして記録 | フェーズ4（本計画のスコープ外） |
| 8. directory-structure.md・index.mdが新構成を反映 | 方針4 |
