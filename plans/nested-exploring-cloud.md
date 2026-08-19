# 全体作業計画: ワークフロー機構の単体テストを `tests/` から `.claude/scripts/test/` へ移動する（issue #63）

## Context

このリポジトリは issue駆動MRワークフロー機構（`.claude/` 一式）のテンプレートであり、
`apply-mr-workflow-to-project` スキルの `sync-assets.sh` が **`.claude/` `.gemini/` `.github/`
`.gitlab/` ＋ルート直下の数ファイル**を配布対象にしている。

機構自身の単体テスト4本は現在リポジトリ直下の `tests/` にあるため、

- 配布対象に含まれず、導入先プロジェクトにテストが付いてこない
- かといって配布対象へ加えると、導入先プロジェクト本体の `tests/` と場所を取り合う

という状態になっている。テストを `.claude/scripts/test/`（`src/` の兄弟）へ移すことで、
plugin配布単位である `.claude/` の中に収まり、上記2点が同時に解消される
（`sync-assets.sh` は `.claude/*` をそのままコピーするため**スクリプト側の変更は不要**）。

## 前提・リスク（着手前に共有）

issue #63 の備考どおり、**PR #56 が現時点で OPEN のまま**（`tests/test_vcs_provider.sh` と
`.claude/docs/spec/issue-mr-workflow.md` を変更している）。本タスクは main から分岐するため、
`tests/test_vcs_provider.sh` の rename と #56 の変更が **マージ時に rename/modify conflict** に
なる。後からマージする側で解決する必要がある（`git` は rename 追跡ができるため、
`.claude/scripts/test/test_vcs_provider.sh` へ #56 の追加テスト8件を取り込む形の解決になる見込み）。
issue は「#56 マージ後の着手が望ましい」としているが、依頼を受けたため本計画では**先に進める**。

## 作業内容

### 1. ファイル移動（`git mv` で履歴保持）

```
tests/test_extract_frontmatter.sh      → .claude/scripts/test/test_extract_frontmatter.sh
tests/test_update_handoff_progress.sh  → .claude/scripts/test/test_update_handoff_progress.sh
tests/test_usage_tracking.sh           → .claude/scripts/test/test_usage_tracking.sh
tests/test_vcs_provider.sh             → .claude/scripts/test/test_vcs_provider.sh
```

移動後、リポジトリ直下に `tests/` を残さない。

### 2. 各テストの `repo_root` 算出を新しい階層に合わせる

4本とも同じ定型で書かれている（例: `.claude/scripts/test/test_vcs_provider.sh:21-23`）。
階層が1段→3段になるため `..` を `../../..` にするだけでよい。

```bash
script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir="."
repo_root="$(cd "$script_dir/../../.." && pwd)"   # 旧: "$script_dir/.."
```

あわせて各ファイル冒頭コメントの `実行: bash tests/test_*.sh` を新パスへ更新する
（`test_update_handoff_progress.sh` の「`tests/test_vcs_provider.sh` を雛形にした」も同様）。

### 3. 「現在の状態を説明する記述」のパス参照を更新

| ファイル | 箇所 |
|---|---|
| `.claude/scripts/src/extract-frontmatter.sh` | L492 コメント |
| `.claude/scripts/src/update-handoff-progress.sh` | L320 コメント |
| `.claude/scripts/src/vcs/Provider.sh` | L110 コメント |
| `.claude/hooks/post-push-usage-report.sh` | L351 コメント |
| `.claude/rules/shell-script-style.md` | 「テスト」節 L270（配置先と実例） |
| `.claude/rules/directory-structure.md` | ツリー L45 の `tests/` 行を `.claude/scripts/test/` へ移す＋「配置の指針」に一言 |
| `.claude/docs/spec/update-handoff-progress.md` | L89・L91（テスト節） |
| `.claude/docs/spec/issue-mr-workflow.md` | L119・L550（いずれも `## 仕様` 節内） |
| `.claude/docs/spec/shell-scripts.md` | L36（`## 仕様` 節内の `test_vcs_provider.sh` の説明） |
| `index.md` | Directory Structure に `./.claude/scripts/test/` を追加（現状 `tests/` の記載自体が無い） |

**書き換えない**（`.claude/rules/docs-workflow.md` の規定・issue #63 の受け入れ条件）:

- DDR本文すべて（`0009` / `0016` / `0023` / `0028`）
- `.claude/docs/spec/issue-mr-workflow.md` の `## 影響範囲` 節（L831〜L1326）の過去エントリ
- `.claude/docs/spec/shell-scripts.md` の `## 影響範囲` 節（L127〜）の過去エントリ

**判断が要る1件**: `shell-script-style.md` L188・L272 と `shell-scripts.md` L33 が参照する
`tests/test_external_command_server.sh` は**このリポジトリに存在しない**（移植元から持ち込まれた
記述）。移動していないファイルのパスを書き換えると事実と異なるため、**触らない**。
`shell-script-style.md`「テスト」節は L270（実在する `test_vcs_provider.sh`）のみ更新する。

### 4. 設計反映（spec / DDR）

- `.claude/docs/spec/issue-mr-workflow.md` の `## 影響範囲` に issue #63 のエントリを**新規追記**
  （過去エントリは変更しない）。
- **DDR 0029 を新規作成**する: 「機構自身の単体テストは `.claude/scripts/test/` に置く」。
  却下案として「`tests/` のまま `sync-assets.sh` の配布対象に加える」（導入先の `tests/` と衝突）と
  「配布しない」（導入先でテストが回せない）を記録する。
  `.claude/docs/README.md` のDDR一覧にも1行追加する。

## 検証

```bash
# 4本すべてが passed=N failures=0・終了コード0 で終わること
for f in .claude/scripts/test/test_*.sh; do bash -n "$f" && bash "$f"; echo "exit=$?"; done

# リポジトリ直下に tests/ が残っていないこと
[ ! -e tests ] && echo "tests/ removed"

# 移動漏れ・参照漏れの確認（DDR本文と影響範囲節のヒットのみ残るはず）
grep -rn "tests/test_" --include="*.sh" --include="*.md" . | grep -v "^./.git/"

# frontmatter索引の再生成（DDR新規追加分）
bash .claude/scripts/src/extract-frontmatter.sh .
```

`test_usage_tracking.sh` / `test_extract_frontmatter.sh` は一時ディレクトリを作って動くため、
移動前の実行結果（件数）を先に控えておき、移動後に同じ件数で通ることを突き合わせる。

## 進め方

issue-mr-flow のフェーズ3（実装・テスト）→フェーズ4（設計反映）で進める。調査はこの計画作成時に
実測で完了しているため**フェーズ2は省略**する。個別作業計画は
`plans/【実装】【テスト】単体テストの.claude配下への移動.md` と
`plans/【設計反映】テスト配置変更をspec_DDRへ反映.md` の2本に分ける。

非対話セッションのため、人間レビュー往復のステップ（3-3/3-4, 3-8/3-9 等）は実施できない。
`HANDOFF.md` の該当ループ範囲は `[]` のまま残し、実施内容は「やったこと」で補足する
（`.claude/rules/docs-workflow.md` の非対話環境の規定）。
