---
title: 【全体作業計画】MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する
type: plan
description: issue #77 の全体作業計画。敵対的レビュースキル・専任サブエージェント・Provider.shのインラインコメント投稿関数を追加する。
tags: [issue-mr-flow, skill, agent, review]
keywords: [敵対的レビュー, サブエージェント, インラインコメント, Provider.sh, 承認モデル, 確度, 重大度, 非対話セッション, GitLab, discussions]
---

# 全体作業計画: MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する

- issue: [#77](https://github.com/yuki-matsu783/MR-driven-workflow/issues/77)
- ブランチ: `feature-77-adversarial-mr-review-skill`
- PR: [#80](https://github.com/yuki-matsu783/MR-driven-workflow/pull/80)（Draft）

## Context（なぜやるか）

実装・計画・設計反映の各レビュー（flow-id 3-3/3-8・4-3/4-8）は人間の負荷に全面的に依存している。
一方でAI側の自己確認は、自分が書いたものを追認する方向に働きやすく、独立した検証にならない。
このリポジトリには現在、レビューを担うスキルもサブエージェントも存在しない（`.claude/agents/` は
読み取り専用の `issue-mr-resume` のみ）。組み込みの `/code-review` は汎用のバグ探しであり、
このリポジトリ固有の落とし穴（`plans/` の粒度、spec/DDR/rules の二重管理、point-in-time記録の
破壊、DDR番号の衝突、shellの既知の罠）は対象外である。

そこで、**独立コンテキストの専任サブエージェントが意図的に穴を探す「敵対的レビュー」**を機構化し、
指摘をMRへインラインコメントとして投稿できるようにする。

## この計画で確定済みの前提（flow-id 1-4でユーザーと合意）

| 論点 | 決定 |
|---|---|
| issue分割 | **分割しない**。成果物が「1つのスキル＋その動作に必要な部品」で不可分であり、`Provider.sh` の関数だけを切り出しても単体では使い道が無く、5フェーズ40ステップの固定費が本体を上回るため |
| フェーズ2（調査） | **実施する**。インラインコメント投稿APIはこのリポジトリで未使用の領域のため |
| 起動ポリシー | **対話セッションではAIからの自律起動を禁止し、人間が `/adversarial-review` を呼んだときだけ実行する。非対話セッション（人間のレビュー往復を待てない実行環境）でのみ、AIが自律的に起動してよい** |
| GitLab | 実装するだけでなく、**dockerでGitLab CEを立てて実機検証する** |
| レビュー観点 | **スキル本文へ直書きせず、ディレクトリごとの `REVIEW-POINTS.md` として外だしする**（flow-id 3-4のレビューで追加）。対象ファイルのディレクトリからルートまで遡って集めマージする。**別issueへ切り出さず #77 に含める**（観点表が無いと「何を観るか」が定義できず、敵対的レビュー単独ではマージしても実用にならないため） |

## フェーズ2: 調査

`plans/【調査】インラインコメント投稿APIとセッション種別判定.md` を作成し、以下を調べる。
結果は `reports/` のHTMLにもまとめる。

1. **GitHubのインラインコメント投稿**: `gh api repos/{owner}/{repo}/pulls/<n>/reviews` に
   `event=COMMENT` と `comments[]`（`path` / `line` / `side` / `body`）を渡す形を、この PR #80 上で
   実際に投稿して確かめる。確認項目は「複数指摘を1レビューにまとめられるか（通知回数）」
   「diffに含まれない行を指定したときの失敗の仕方」「投稿したスレッドが
   `get_mr_unresolved_comments` の GraphQL `reviewThreads` に `unresolved` として現れるか」。
2. **GitLabのインラインコメント投稿**: `projects/:id/merge_requests/<iid>/discussions` の
   `position` 必須項目（`base_sha` / `start_sha` / `head_sha` / `old_path` / `new_path` /
   `new_line` / `position_type`）と、その取得元（MR JSONの `diff_refs`）を、dockerで立てた
   GitLab CE 上で実機確認する。
3. **非対話セッションの機械的な判定方法**: **第一候補は環境変数 `AUTOMATION`**（`AUTOMATION=1`
   なら非対話モード、それ以外は対話モード）。この変数が実際にどの実行環境で・どの値で設定される
   のかを実機で確認する（対話セッションであるこのセッションで `unset` になること、および
   非対話実行環境で `1` になることの裏取り）。裏取りできない場合に備え、`get_vcs_access_mode` の
   戻り値・hookに渡るJSONなど代替材料も併せて調べる。**いずれも確定できなければ「既定は起動禁止、
   明示フラグでのみ非対話モードを有効化」**に倒す（＝`AUTOMATION` 未設定は常に対話モード扱い）。
   判定はスキルの**手順1**（他のどの手順よりも先・スキップ不可）として書く。
4. **MCP経路でのインライン投稿**: `mcp__github__*` にインラインレビューを作れるツールがあるかを
   確認し、`issue-mr-flow/SKILL.md` の対応表に追記できる形にする。無ければ「MCP経路では
   インライン投稿を行わず、通常コメント1件へ集約する」という縮退を定める。

## フェーズ3: 設計・実装

`plans/【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント.md` を作成して進める。

### 3-a. `Provider.sh` へのインラインコメント投稿関数

既存の `add_mr_thread_reply` / `add_mr_comment`（[.claude/scripts/src/vcs/Provider.sh:397](.claude/scripts/src/vcs/Provider.sh#L397),
[:478](.claude/scripts/src/vcs/Provider.sh#L478)）と同じディスパッチ形式に揃える。

- `add_mr_inline_comments <MR番号> <findings JSONファイル>` を追加し、
  `github_add_mr_inline_comments` / `gitlab_add_mr_inline_comments` へ振り分ける。
  **findingsは必ずファイル経由で渡す**（`jq: Argument list too long` と、コマンド文字列への
  `git push` 等の混入によるhook誤検知の両方を避けるため。`.claude/rules/shell-script-style.md`）。
- 純粋ロジックは以下へ切り出し、`gh`/`glab` を呼ばない形にして単体テスト可能にする。
  - `filter_findings_for_posting`: 確度・重大度による投稿／報告の振り分け
  - `github_build_review_payload`: findings JSON → `gh api --input` へ渡すレビューJSON
  - `gitlab_build_discussion_form`: finding 1件 + `diff_refs` → `position[...]` パラメータ
- findings JSONのスキーマ（案）:

  ```json
  {"findings":[{"path":".claude/scripts/src/x.sh","line":42,"side":"RIGHT",
    "severity":"major","confidence":"high","category":"shell-pitfall",
    "title":"...","body":"..."}]}
  ```

- 投稿／報告の基準（案。フェーズ3のレビューで確定する）:

  | 確度 \ 重大度 | blocker | major | minor | nit |
  |---|---|---|---|---|
  | high | 投稿 | 投稿 | 投稿 | 報告 |
  | medium | 投稿 | 投稿 | 報告 | 報告 |
  | low | 報告 | 報告 | 報告 | 報告 |

  加えて1回あたりの投稿上限（既定10件）を設け、超過分は重大度順に絞って残りは報告に回す。

### 3-b. 専任サブエージェント `.claude/agents/adversarial-reviewer.md`

`issue-mr-resume.md` と同じfrontmatter形式（`name` / `description` / `tools` / `model` ＋
`.claude/rules/markdown-frontmatter.md` のキー）に従う。

- **読み取り専用**（`Read, Grep, Glob, Bash`）。findings JSONを標準の形で返すだけで、投稿は行わない。
  投稿は呼び出し元（スキル）の責務にし、承認の所在を1箇所へ寄せる。
- 実装した本人の文脈に引きずられないよう、**渡すのは「diffとファイルパスだけ」**とし、
  「なぜそう実装したか」の経緯は渡さない。
- `model: opus`（浅い確認では敵対的レビューにならないため。`issue-mr-resume` の `sonnet` とは
  役割が異なる）。

### 3-c. 実施回数の記録（無限ループ防止）

非対話モードでは「レビュー → 修正 → 再レビュー」が人間の介在なく回りうるため、**実施回数を
機械的に記録し、各フェーズ最大3回で打ち切る**。AIの自制ではなくスクリプトで強制する。

- `.claude/scripts/src/adversarial-review-count.sh` を追加し、`get <phase>` /
  `increment <phase>` / `reset` のサブコマンドを持たせる。上限に達している場合は `increment` が
  終了コード1と理由メッセージを返し、スキルはそこで打ち切って報告のみを行う。
- 状態は `.claude/state/adversarial-review/<ブランチ名>.json` に `{"2":N,"3":N,"4":N}` の形で持つ
  （`.claude/state/` は既にローカル作業状態用で `.gitignore` 対象。`usage/` とは責務が異なるため
  混ぜない）。ブランチ単位のため、`main` へマージすれば自然に消える。
- フェーズ番号はレビュー対象の判別（3-dの表）と同じ材料から決める。判別できない場合は
  ユーザーに選ばせ、非対話モードでは「diff全体（フェーズ3）」を既定とする。
- カウンタ更新は**投稿の成否に関わらずレビュー実行の直後**に行う（失敗を理由に無限に
  リトライできてしまうことを防ぐ）。上限・状態ファイルのパスの取り扱いは純粋関数へ切り出し、
  `.claude/scripts/test/` に単体テストを追加する。

### 3-d. スキル `.claude/skills/adversarial-review/SKILL.md`

- **冒頭に組み込み `/code-review` との棲み分けを明記**する（`/code-review` は汎用のバグ探しで
  コードが対象。本スキルはこのリポジトリの運用規約・ドキュメント整合まで含み、指摘をMRへ
  インライン投稿する）。
- **手順1を「実行モードの判定」にする**（他のどの手順よりも先・スキップ不可）。
  `echo "AUTOMATION=${AUTOMATION:-unset}"` を実行し、`1` なら非対話モード、それ以外は対話モード
  として以降の分岐を決める（フェーズ2の調査結果で確定する）。
- **起動ポリシーを絶対ルールとして書く**: 対話セッションではAIから自律起動しない。人間が
  `/adversarial-review` を呼んだときのみ実行する。非対話セッションでのみ自律起動を許す。
- **実施回数の上限を手順として組み込む**: 3-c のカウンタを確認し、当該フェーズで既に3回
  実施済みなら**レビューを実行せずに打ち切る**（打ち切った事実は報告し、`HANDOFF.md` にも残す）。
- **承認モデル**: 起動時に `AskUserQuestion` で投稿可否を1回だけ確認し、承認後は指摘ごとの
  個別承認を求めない。非承認なら報告のみに留める。
- **レビュー対象3種と観点**を具体的に定義する。現在のflow-idから自動判別し、曖昧なら選択させる。

  | 対象 | 判別 | 観点（リポジトリ固有のものを含む） |
  |---|---|---|
  | diff全体 | 3-7/4-7直後 | `.claude/rules/shell-script-style.md` の既知の罠（外部プロセス起動コスト、`jq`の引数長、NULバイトとコマンド置換、`${N:-\{\}}`、CR混入、終了コード検査、日本語の部分文字列）／hook誤検知語（`git`＋`commit`/`push` の連続）／`.ps1`のBOM／フロー定義との齟齬 |
  | `plans/` の個別計画 | 2-2/3-2/4-2直後 | 種別`【】`の妥当性・併記/分割の判断・受け入れ条件との対応漏れ・planツールの誤用・issue分割トリガー（並列列挙構造） |
  | 設計反映 | 4-7直後 | spec/DDR/rulesの二重管理・DDR本文の不変性・point-in-time記録（changelog）の破壊・DDR番号の衝突・`docs-workflow.md` の表との整合・見出し挿入位置の係り受け（issue #64） |

- **`gh`/`glab` 不在時（`get_vcs_access_mode` が `mcp`）の読み替え**を節として持たせる。
- **`issue-mr-flow/SKILL.md` への追記**: 全体フロー表は変えず、「敵対的レビューの位置づけ」節を
  追加して、push直後・人間レビュー前という位置と、対話セッションでの自律起動禁止を書く。
  挿入位置は直前の節の地の文の係り先を壊さない場所を選ぶ（`docs-workflow.md` の注意点）。

### 3-e. テスト

`.claude/scripts/test/test_vcs_provider.sh` に 3-a の純粋関数のケースを追加する（既存の
`gitlab_format_discussion_notes` のテストと同じ形）。境界値として「findingsが0件」
「投稿対象が0件（全件が報告行き）」「上限超過」「`path`にマルチバイト文字」を含める。

## フェーズ4: 反映

- **設計反映**: `.claude/docs/spec/adversarial-review.md`（新規）と、
  `.claude/docs/ddr/00NN-敵対的レビューは専任サブエージェントで独立コンテキストに切り出す.md`
  （新規。採用理由と却下案 —「`/code-review` の拡張で済ませる」「メインエージェントの自己レビュー」
  「指摘ごとに個別承認」「常に必須ステップにする」— を記録）。DDR番号はマージ直前に `main` の
  最新と突き合わせて確定する（衝突しやすいため）。
- **AIアセット反映**: 上記とは別ファイル・別レビューで行う（`【設計反映】`と`【AIアセット反映】`は
  併記しない方針）。`.claude/rules/` 側に反映すべき知見があればここで扱う。

## 検証

```bash
bash -n .claude/scripts/src/vcs/Provider.sh .claude/scripts/src/vcs/Github.sh .claude/scripts/src/vcs/Gitlab.sh
bash .claude/scripts/test/test_vcs_provider.sh        # passed=N failures=0
bash .claude/scripts/src/extract-frontmatter.sh .     # 新規mdのfrontmatterが拾えること
```

- **GitHub実機**: この PR #80 に対して敵対的レビューを実行し、インラインコメントが意図した
  ファイル・行に付くこと、`comments` サブコマンドで `unresolved` として取得できることを確認する。
  確認後のコメントは片付ける。
- **GitLab実機**: dockerでGitLab CEを起動し、テスト用プロジェクト・MRを作って
  `gitlab_add_mr_inline_comments` が position 付きで投稿できることを確認する。
- **縮退の確認**: `PATH` から `gh` を外した状態で `get_vcs_access_mode` が `mcp` を返し、
  `require_vcs_cli` が代替MCPツール名を提示して失敗すること。

## スコープ外・リスク

- スレッドの解決（resolve）操作は行わない（レビュアー側の操作という既存方針を踏襲）。
- 敵対的レビューの結果でマージをブロックする仕組み（CI連携等）は作らない。
- リスク: dockerでのGitLab CE起動は時間がかかる。フェーズ2で立ち上げたコンテナはフェーズ3の
  検証まで使い回し、作業完了後に停止・削除する。
- リスク: 非対話セッションの機械的判定に確実な材料が無い場合、既定を「起動禁止」に倒すため、
  非対話環境でも明示設定なしには動かない。この制約はspecの未決定事項として残す。
