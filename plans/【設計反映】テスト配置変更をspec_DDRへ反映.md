# 【設計反映】テスト配置変更を spec / DDR へ反映（issue #63）

全体作業計画: `plans/nested-exploring-cloud.md`

## 反映先

| ファイル | 内容 |
|---|---|
| `.claude/rules/directory-structure.md` | ツリーの `tests/` 行を `.claude/scripts/` 配下の `test/` へ移動。「配置の指針」へ `test/` の役割を1行追記 |
| `.claude/rules/shell-script-style.md` | 「テスト」節の配置先を `.claude/scripts/test/` へ。`.claude/` 配下へ収める理由（導入先の `tests/` と衝突しない）を併記 |
| `index.md` | Directory Structure へ `./.claude/scripts/test/` を追加（現状 `tests/` の記載自体が無い） |
| `.claude/docs/spec/issue-mr-workflow.md` | 「## 仕様」節内のパス参照2箇所を更新。「## 影響範囲」へ issue #63 のエントリを**新規追記** |
| `.claude/docs/spec/update-handoff-progress.md` | 「テスト」節のパス参照2箇所 |
| `.claude/docs/spec/shell-scripts.md` | 「## 仕様」節内の `test_vcs_provider.sh` の説明のみ（当時のパスを併記して現在地を示す） |
| `.claude/docs/ddr/0029-*.md` | 新規。却下案として「`tests/` のまま配布対象へ追加」「配布しない」「`.claude/tests/`」を記録 |
| `.claude/docs/README.md` | DDR一覧へ0029を追加 |

## 書き換えない範囲（`.claude/rules/docs-workflow.md` の規定）

- DDR本文すべて（`0009` / `0016` / `0023` / `0028`）
- `.claude/docs/spec/issue-mr-workflow.md` の「## 影響範囲」の過去エントリ
- `.claude/docs/spec/shell-scripts.md` の「## 影響範囲」の過去エントリ

`git diff -U0` の削除行のみを抽出し、現在の状態を説明する記述だけが消えていることを確認する。
