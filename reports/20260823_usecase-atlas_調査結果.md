---
title: 調査結果 ユースケース文書の対象と構成の確定
type: report
description: issue #170フェーズ2調査の結果。初期ユースケース8件の採用・命名規則・目次の形・検索対応・4-6差し込み位置・周辺波及の結論
tags: [usecase-docs, report, research]
keywords: [ユースケース, 逆引き, 命名規則, doc-search, type usecase, README目次, flow-id 4-6, 波及]
---

# 調査結果: ユースケース文書の対象と構成の確定

- issue: #170 / PR: #173
- 個別調査計画: `plans/【調査】ユースケース文書の対象と構成の確定.md`（7つの問い）
- 実施日: 2026-08-23

## サマリ（結論の一覧）

| # | 問い | 結論 |
|---|---|---|
| 1 | 8件の実在確認 | **8件すべて対応機能が現存**。リンク先は下表のとおり全ファイルの実在を確認済み |
| 2 | 取捨選択・追加 | **8件をそのまま採用**（統合・除外・追加なし。commitスキル等はフロー内部の1ステップでありエントリポイントでないため独立文書にしない） |
| 3 | 命名規則 | **日本語タイトル＝ファイル名**（例: `新しい機能開発を始める.md`）。番号プレフィックスは付けない |
| 4 | 目次の要否 | **`.claude/docs/README.md` のusecase節へ一本化**。`usecase/` 直下に独立目次は置かない |
| 5 | 検索対応 | **スクリプト変更不要**（`--type` は任意値の完全一致。実機確認済み） |
| 6 | 4-6差し込み位置 | SKILL.md 4-6行の作業内訳**「設計反映」項の末尾**へ追記。spec側はフロー表を持たないため変更不要 |
| 7 | 周辺波及 | 変更6ファイル（下表の行数ではなく変更するファイル数。観点表1件を含めて7ファイル）。配布物は変更不要 |

## 実施した内容と結果

### 問い1・2: ユースケース一覧（8件、リンク先実在確認済み）

作成するファイルと、各文書が「詳細へのリンク」として指す先。リンク先は実ファイルの存在を
確認した（`ls`・`Read`）。

| ファイル名（`.claude/docs/usecase/` 配下） | 場面 | 使う機能 | 主なリンク先 |
|---|---|---|---|
| `新しい機能開発を始める.md` | 機能追加・変更をissue起点で始めたい | `issue-create` スキル → 別セッションで `/issue-mr-flow start` | `.claude/skills/issue-create/SKILL.md`・`.claude/skills/issue-mr-flow/SKILL.md`・`.claude/docs/spec/issue-mr-workflow.md` |
| `途中の作業を再開・引き継ぐ.md` | 中断した作業・他者の作業を続きから進めたい | `/issue-mr-flow resume`・HANDOFF.md | `.claude/skills/issue-mr-flow/SKILL.md`「resume」・`.claude/agents/issue-mr-resume.md`・`HANDOFF.md`・`.claude/docs/spec/check-base-sync.md` |
| `生成物にレビューコメントして修正させる.md` | AIの成果物へ指摘して直させたい | PR/MRレビューコメント＋`/issue-mr-flow comments`/`reply` | `.claude/skills/issue-mr-flow/SKILL.md`「comments」「reply」・`.claude/docs/spec/issue-mr-workflow.md`「レビューコメントのソーススライス」 |
| `レビューをAIに補助してもらう.md` | 人間レビューの前にAIに欠陥を探させたい | `adversarial-review`・`review-points` スキル | `.claude/skills/adversarial-review/SKILL.md`・`.claude/skills/review-points/SKILL.md`・`.claude/docs/spec/adversarial-review.md` |
| `ベースブランチとのコンフリクトを解消する.md` | mainが進んでコンフリクト・遅れが出た | `resolve-conflict` スキル・check-base-sync/conflicts | `.claude/skills/resolve-conflict/SKILL.md`・`.claude/docs/spec/check-base-conflicts.md`・`.claude/docs/spec/check-base-sync.md` |
| `リポジトリ内のドキュメントを探す.md` | 目的のspec/DDR/ルールを素早く見つけたい | `doc-search` スキル（frontmatterインデックス） | `.claude/skills/doc-search/SKILL.md`・`.claude/docs/spec/search-frontmatter.md`・`.claude/rules/markdown-frontmatter.md` |
| `対応工数を把握する.md` | issue対応にかかった工数を集計したい | push検知hookの工数レポート・push断面ログ | `.claude/hooks/post-push-usage-report.sh`・`.claude/docs/spec/issue-mr-workflow.md`「対応工数レポート」・`.claude/scripts/src/show-push-log.sh`・`.claude/docs/spec/otel-listener.md`（関連） |
| `この機構を他プロジェクトへ導入する.md` | 別リポジトリへこのワークフロー一式を入れたい | `apply-mr-workflow-to-project` スキル | `.claude/skills/apply-mr-workflow-to-project/SKILL.md`・`.claude/docs/spec/distribution-assets.md` |

追加候補として検討し**採用しなかった**もの:

- コミットの作成（`commit` スキル）・調査レポートの視覚化（`canvas-report`）・issue分割:
  いずれも開発フローの**内部の1ステップ**であり、「やりたいこと」として単独で入り口になる場面が
  無い。該当するusecase文書（上表の1件目・3件目）の本文からリンクで触れるに留める。
- テレメトリ収集（OTelリスナー）: 単独のユースケースとしては薄く、「対応工数を把握する」の
  関連リンクとして扱う。

**取りこぼしの突き合わせ根拠**（スキル9本＝`ls .claude/skills/*/SKILL.md`・hook 5本＋otel）:

| スキル / hook | どのusecaseから辿れるか（または単独にしない理由） |
|---|---|
| `issue-create` | 新しい機能開発を始める |
| `issue-mr-flow` | 新しい機能開発を始める／途中の作業を再開・引き継ぐ／生成物にレビューコメントして修正させる |
| `adversarial-review`・`review-points` | レビューをAIに補助してもらう |
| `resolve-conflict` | ベースブランチとのコンフリクトを解消する |
| `doc-search` | リポジトリ内のドキュメントを探す |
| `apply-mr-workflow-to-project` | この機構を他プロジェクトへ導入する |
| `commit` | フロー内部の1ステップ（上記のとおり単独ユースケースにしない。「新しい機能開発を始める」から言及） |
| `canvas-report` | フロー内部の1ステップ（同上） |
| hook: `post-push-usage-report.sh`・`show-push-log.sh`・otel | 対応工数を把握する |
| hook: `session-start.sh`・`post-push-compact-prompt.sh`・`block-direct-git-commit.sh`・`post-issue-create-notice.sh` | フローの自動補助であり人間が能動的に使う入り口ではない（該当usecase文書の本文で必要に応じて言及） |

### 問い3: 命名規則 — 日本語タイトル＝ファイル名

- **採用**: `どんな場面か`をそのまま表す日本語のファイル名（frontmatter `title`・本文H1と一致させる）。
  読み手（人間）が一覧を見ただけで場面を選べることが逆引き層の目的であり、DDRで日本語ファイル名の
  運用実績がある（マルチバイトパスの罠は既存ルールで整理済み。`-c core.quotepath=false` 等）。
- **却下: 英語kebab-case**（spec形式）: specとの見た目の整合はあるが、ファイル名と内容の対応を
  読み手が翻訳する一手間が入り、逆引きの目的に反する。
- **却下: 番号プレフィックス**（`01-〜.md`）: 並び順はREADME目次が持つため不要。挿入時の
  振り直しコストと、番号と内容の不一致リスクだけが残る。

### 問い4: 目次 — `.claude/docs/README.md` へ一本化

`usecase/` 直下に独立のREADME/目次は**置かない**。一覧の正が2箇所になると片方が必ず古くなる
（ルートのREVIEW-POINTS.md「正は1箇所に決め、他はそこを指すリンクだけにする」）。
`.claude/docs/README.md` に「usecase（ユースケース逆引き）」節を追加し、8件を場面の一言説明付きで
列挙する。現状8件であればREADME内の一覧で十分に一覧できる。

**一覧を最新に保つ責任も決める**: `.claude/rules/docs-workflow.md` のusecase行の運用欄へ
「usecase文書を追加・改名・削除したら `.claude/docs/README.md` のusecase節を同じコミットで
更新する」を含める（問い7の表に反映済み）。DDR一覧のような**生成物化は現時点では採らない**
（8件規模では生成スクリプトの導入・保守コストが手動更新を上回る。DDRと違い並び順が意味を持つ
＝場面の重要度順に人が並べるため、機械的なソートも馴染まない）。件数が増えて手動更新の漏れが
実際に起きたら、issue #135と同じ生成物化を別issueで検討する。

### 問い5: 検索対応 — スクリプト変更不要（実機確認）

- `search-frontmatter.sh` の `--type` は「frontmatterの `type` と大文字小文字を無視した完全一致」で、
  値の妥当性検証（enum）は行わない（`match_exact` の定義211行目・`--type` での使用229行目。
  許容値リスト `SF_SORT_KEYS`/`SF_FORMATS`（40〜41行目）は `--sort`/`--format` にしか無い。
  行番号は2026-08-23時点の実装のもの）。
  実機で `--type spec --format count` が `matched=15 total=129` を返すことを確認した
  （2026-08-23・Linuxリモート実行環境。`total` はインデックス全件数のため時点依存の値）。
- `extract-frontmatter.sh` は `type` を抽出するだけで値を検証しない。走査は
  `git ls-files --cached --others --exclude-standard` のため、`.gitignore` 対象でなければ
  **未追跡（コミット前）のファイルでもインデックスへ載る**。
- したがって受け入れ条件「`--type usecase` で絞り込める」は、**文書側のfrontmatterと
  規約表への追記だけで満たせる**見込み（推論）。`--type usecase` そのものの実測は、
  `type: usecase` のファイルが生まれるフェーズ3の作成直後に行う。

### 問い6: flow-id 4-6への差し込み — 「設計反映」項の末尾

- SKILL.md の 4-6 行は表のセル内に「（**設計反映**: …／**AIアセット反映**: …／**実装反映**: …）」
  の3項を持つ。ユースケース文書への影響確認は**「設計反映」項の末尾**（generate-ddr-list.sh の
  文の後）へ「あわせて、変更が `.claude/docs/usecase/` のユースケース文書に影響するか
  （記述・リンクが古くならないか）を確認し、影響があれば更新する」の形で追記する。
  セル内の追記であり、節見出しの挿入ではないため「直前の節の地の文の係り先」問題は生じない。
- `.claude/docs/spec/issue-mr-workflow.md` の「全体フロー」節は**表を持たず**SKILL.mdへの参照のみ
  （実物で確認）。spec側の変更は不要。
- `.claude/rules/docs-workflow.md` の「ドキュメント運用」表には、usecase文書の寿命・運用を
  1行追加する（下記問い7）。

### 問い7: 周辺ドキュメントへの波及（フェーズ3で変更するファイルの確定）

| ファイル | 変更内容 |
|---|---|
| `.claude/rules/markdown-frontmatter.md` | 「typeの値」表へ `usecase` → `.claude/docs/usecase/*.md` の行を追加 |
| `.claude/docs/README.md` | 冒頭の `spec/`・`ddr/` 箇条書きへ `usecase/` を追加し、「usecase（ユースケース逆引き）」節（8件の一覧）を追加。**節は生成マーカー区間（`BEGIN GENERATED: ddr-list`〜`END GENERATED`、79〜155行）の外へ置く**（内側に置くと `generate-ddr-list.sh` の次回実行で無言で消える）。**frontmatterの `description`/`keywords`（spec・ddrの2分類前提の記述）も更新する** |
| `.claude/skills/issue-mr-flow/SKILL.md` | 4-6行の「設計反映」項末尾へ影響確認を追記（問い6） |
| `.claude/rules/docs-workflow.md` | 「ドキュメント運用」表へusecase文書の行を追加（対象: 人間＋AI／寿命: 永続（最新状態）／運用: 機能の追加・変更時にflow-id 4-6で影響を確認し更新する。**usecase文書を追加・改名・削除したら `.claude/docs/README.md` のusecase節を同じコミットで更新する**） |
| `.claude/rules/directory-structure.md` | ツリーの `.claude/docs/` 配下へ `usecase/` の行を追加 |
| `index.md` | Repository Mapの `.claude/docs/` 配下へ `usecase/` の行を追加 |
| `.claude/REVIEW-POINTS.md` | 「usecase文書は手順詳細（コマンド列・手順番号）を再掲せず、spec/SKILL.mdへのリンクで参照する」観点を追加（受け入れ条件「重複記載しない」の継続的な検査手段。機械検査＝コードブロック0と併用） |
| 配布物（`sync-assets.sh`・distribution-assets） | **変更不要**。`sync-assets.sh` は `.claude/` 配下を（apply-mr-workflow-to-projectスキルを除き）丸ごとコピーするため、`usecase/` は自動で配布対象になる（実装16〜40行目で確認） |

## 確かめられなかったこと

- 日本語ファイル名のusecase文書がWindows実機（git bash・cp932環境）で問題なく扱えるかは、
  この環境（Linux）では確認できない。ただしDDR 75本が同じ形式（日本語ファイル名）で運用済みの
  ため、リスクは新規ではない。
- **`--type usecase` そのものは未実測**（この時点では `type: usecase` のファイルが存在しないため。
  実測したのは既存値 `--type spec`）。問い5の結論はスクリプト実装の読解＋既存typeの実測に基づく
  推論であり、フェーズ3でusecase文書を1本作った直後に実測して裏を取る。

## 設計への反映

- 本調査の結論（配置・命名・目次一本化・typeの新設）は、フェーズ4でDDRとして残すかを flow-id 4-1
  で判断する（全体作業計画「フェーズ4〈反映〉」の候補に含まれている）。
- フェーズ3の個別作業計画は、本レポートの問い7の表＋問い1の一覧をそのまま「変更対象」にできる。
- フェーズ3の検証手順へ「usecase文書を1本作った直後に `extract-frontmatter.sh` →
  `search-frontmatter.sh --type usecase` を実測する」を含める（未追跡でも載るため、コミットを
  待つ必要は無い）。
