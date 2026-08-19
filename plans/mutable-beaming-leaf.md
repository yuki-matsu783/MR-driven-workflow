# issue #48 全体作業計画: Gitlab.shの3件の不具合を修正する

/ issue: [#48](https://github.com/yuki-matsu783/MR-driven-workflow/issues/48)
/ ブランチ: `feature-48-fix-gitlab-sh-verified-defects`
/ PR: [#49](https://github.com/yuki-matsu783/MR-driven-workflow/pull/49) (Draft)

## Context

`.claude/scripts/src/vcs/Gitlab.sh` は全関数に `【未検証】` と明記されたまま運用されていた。
issue #45（self-hosted GitLabをプロバイダ判定できない）の実機検証のため、ローカルに
GitLab CE 18.5.4 を立てて全13関数を実行したところ、**全関数が動作した一方で、self-hosted判定とは
独立した3件の不具合**が見つかった。本issueはその3件を修正する。

3件はいずれも「GitHubの挙動をGitLabにも当てはめた推測」または「GitLab固有のAPI仕様の見落とし」に
起因する。特に③はレビュー往復の完了判定を狂わせる実害がある。

### 検証環境（再現・再検証に使う）

| | |
|---|---|
| GitLab | CE 18.5.4（Dockerコンテナ `gitlab`、`http://localhost:8929`） |
| glab | 1.114.0（`localhost:8929` に root で認証済み） |
| 検証用プロジェクト | `root/issue45-verify`（MR !1・issue #1 作成済み） |

`get_provider` がself-hosted URLを弾く（issue #45、未修正）ため、検証は `gitlab_*` 関数を
**直接呼ぶ**形で行う。Provider.sh経由のディスパッチは本issueの対象外。

## フェーズ方針

**フェーズ2（調査）は省略する。** 上記の実機検証が調査に相当し、3件の原因・再現条件・
期待動作はissue #48に確定済みのため。フェーズ3（作業）から入る。

## フェーズ3: 実装・テスト

個別作業計画は `plans/【実装】【テスト】Gitlab.shの3件の不具合修正.md` として1ファイルにまとめる
（3件とも同一ファイルの小さな修正で、合意の単位を分ける必要が無いため）。

### ① 空コミットフォールバックの前提誤り

`gitlab_new_draft_merge_request`（[Gitlab.sh:45-59](../.claude/scripts/src/vcs/Gitlab.sh#L45-L59)）

- **コードは残し、コメントを実態に合わせて書き換える。**
- 実測: GitLab 18.5.4 では main と同一SHAのブランチでも `glab mr create` が成功し、
  フォールバックは発動しなかった。一方GitHubでは本ブランチ作成時に実際に
  `No commits between main and feature-48-...` が発生しフォールバックが動作した。
  → **この制約はGitHub固有**である。
- 削除ではなく残す理由: 検証できたのは18.5.4の1バージョンのみで、他バージョン・他設定で
  `glab mr create` が失敗する可能性を否定できない。フォールバックは安全網として無害。
  ただし「GitLabでは通常到達しない安全網であり、GitHub由来の制約である」旨をコメントに明記し、
  読み手が誤った前提を引き継がないようにする。

### ② `glab mr note --message` の非推奨

`gitlab_add_mr_comment`（[Gitlab.sh:144-149](../.claude/scripts/src/vcs/Gitlab.sh#L144-L149)）

- `glab mr note "$n" --message "$body"` → **`glab api "projects/:id/merge_requests/$n/notes" -X POST -f "body=$body"`** へ置き換える。
- 直下の `gitlab_add_mr_thread_reply` が既に同じ `glab api` 方式で書かれており、**実装が揃う**。
- `glab mr note create` を採用しない理由: 非推奨を回避できる代わりに **EXPERIMENTAL** 扱いであり、
  安定版のREST APIへ寄せる方が寿命が長い。

### ③ システムノートの混入

`gitlab_get_mr_unresolved_comments`（[Gitlab.sh:66-82](../.claude/scripts/src/vcs/Gitlab.sh#L66-L82)）

- jqフィルタに **`select(.system | not)`** を追加し、GitLabが自動生成するノートを除外する。
- あわせて**jqフィルタを純粋関数へ切り出す**（例: `gitlab_format_discussion_notes`。
  discussions JSONを引数で受け取り整形済み文字列を返す）。`gitlab_get_mr_unresolved_comments` は
  `glab api` 呼び出し＋この関数の薄いラッパーにする。
  - 目的は**単体テスト可能にすること**。`.claude/rules/shell-script-style.md`「テスト」の
    「副作用の無い純粋ロジックは `tests/` に置く」に沿う。
- GitHub側（`github_get_mr_unresolved_comments`）はGraphQLの `reviewThreads` / `comments` を
  使っており、システムイベントを返さないため**同種の問題は無い**。修正不要。

### テスト

`tests/test_vcs_provider.sh` に追記する（既存の `assert_eq` / `passed=N failures=N` 規約に従う）。

- `gitlab_format_discussion_notes` に対し、**実測したペイロード形状**をフィクスチャにしたケースを追加:
  - `system=true` のノート（`changed the description`）が**出力されない**
  - `system=false, resolvable=true, resolved=false` のノートが `unresolved` として出力される
  - `include_resolved=true` で解決済みも含まれる
- 既存の純粋関数テストが退行しないこと。

## フェーズ4: 反映

`【設計反映】` と `【AIアセット反映】` は分けて実施する（`.claude/skills/issue-mr-flow/SKILL.md`）。

### 設計反映

- `.claude/docs/spec/issue-mr-workflow.md` の **「### Draft PR作成失敗時の自動リトライ」節（L259-265、現在の状態を説明する節）** を、
  「GitHub固有の制約であり、GitLab 18.5.4では差分ゼロでもMR作成が成功することを実機確認した」旨へ更新する。
- **同ファイルL1238-1250（issue #15のchangelogエントリ）は書き換えない。** `.claude/rules/docs-workflow.md`
  の「point-in-timeの記録として書かれた節は一括置換の対象に含めない」に該当する。issue #48の変更は
  **changelogへの新規エントリ追記**として残す。
- **DDR 0005 は本文・frontmatterとも変更しない。** GitHubについては決定内容が現在も有効であり、
  `superseded` にも `deprecated` にも当たらないため。

### AIアセット反映

- `Gitlab.sh` 冒頭および各関数の `【未検証】` コメントを実態に合わせて更新する（検証済みの関数と、
  依然未検証の範囲を区別して記述する）。
- 実機検証で判明した運用上の知見のうち、ルール化すべきものがあれば `.claude/rules/` へ反映する
  （候補: git bashから `docker exec` を使う際の `MSYS_NO_PATHCONV=1`、GitLabのPATが
  ドットを含む形式であること。フェーズ4で要否を判断する）。

## 変更対象ファイル

| ファイル | 内容 |
|---|---|
| `.claude/scripts/src/vcs/Gitlab.sh` | ①コメント修正 ②`glab api`へ置換 ③`select(.system|not)`＋純粋関数切り出し |
| `tests/test_vcs_provider.sh` | ③の純粋関数に対するテスト追加 |
| `.claude/docs/spec/issue-mr-workflow.md` | 現状節の訂正＋changelog新規エントリ（フェーズ4） |
| `HANDOFF.md` | flow-idが進むごとに更新 |

## 検証方法

1. `bash -n .claude/scripts/src/vcs/Gitlab.sh` で構文チェック
2. `bash tests/test_vcs_provider.sh` → `passed=N failures=0`
3. **ローカルGitLabで全13関数を再実行**し退行が無いことを確認する
   （コンテナ `gitlab` を起動 → `cd <scratchpad>/issue45-verify` →
   `source Provider.sh` → `gitlab_*` を直接呼ぶ）
   - ② 非推奨警告が出ないこと
   - ③ `changed the description` が出力に含まれないこと
   - ①③以外の関数の出力が検証時と一致すること
4. 合成フィクスチャのテストだけで完了としない（`.claude/rules/shell-script-style.md`の
   「実データでしか顕在化しない性質がある」）。3.の実機確認を必ず行う。

## 未確定事項

- ①でフォールバックを「残す」判断は、GitLab 18.5.4 単一バージョンの実測に基づく。
  他バージョンでの挙動は未確認であり、この前提は明示的にコメントへ残す。
- AIアセット反映の対象（`MSYS_NO_PATHCONV` 等をルール化するか）はフェーズ4で判断する。
