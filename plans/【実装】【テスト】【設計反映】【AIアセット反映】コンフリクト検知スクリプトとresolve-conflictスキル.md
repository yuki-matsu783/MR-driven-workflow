---
title: 個別作業計画 コンフリクト検知スクリプトとresolve-conflictスキル
type: log
description: issue #46の実装・テスト・設計反映・AIアセット反映を1ファイルにまとめた個別作業計画（非対話的環境のため合意は1回）
tags: [plan, conflict, implementation]
keywords: [check-base-conflicts, resolve-conflict, merge-tree, DDR番号, flow-id-5-2, issue-46]
---

# 【実装】【テスト】【設計反映】【AIアセット反映】コンフリクト検知スクリプトとresolve-conflictスキル

**種別を4つ併記している理由**: 非対話的実行環境のため、フェーズごとに人間の合意を挟めない
（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」の判断基準では
本来分けるべきだが、分けても合意の単位が変わらないため併記した）。

## 1. 【実装】`.claude/scripts/src/check-base-conflicts.sh`

- 引数: `--base <branch>` / `--head <ref>` / `--no-fetch`
- 出力: 判定JSON（`hasConflict` / `hasTextualConflict` / `textualConflictFiles` /
  `hasDuplicateDdrNumber` / `duplicateDdrNumbers`）
- 終了コードは「検査できたか」だけを表し、コンフリクトの有無はJSONで返す
  （呼び出し元が `set -e` 配下でも止まらないため）
- 検知1: `git -c core.quotepath=false merge-tree --write-tree --name-only --no-messages`
  （作業ツリー非破壊）。1行目のツリーOIDは落とす
- 検知2: 両ブランチのツリーからDDRを `git ls-tree -r` で列挙し、先頭4桁の連番でグルーピング
- 純粋関数 `ddr_number_to_reply` / `find_duplicate_ddr_numbers` に分離し、ループ内で外部コマンドを
  呼ばない（`.claude/rules/shell-script-style.md`）
- JSON組み立ては `jq` 1回。可変長データは `--arg` ではなく標準入力から読ませる
- `main` の呼び出しは `BASH_SOURCE`/`$0` 比較でガード（テストからsourceできるように）

## 2. 【テスト】`tests/test_check_base_conflicts.sh`

- 対象は純粋関数のみ（git操作を伴う `main` は対象外）
- `passed=N failures=N` を出力し、失敗があれば終了コード1
- 終了コードの検査は `if func; then` の形で受ける（`"$(func; echo $?)"` は使わない）
- PR #52で実際に起きた「別名で同じ0027」を再現するケースを含める
- **加えて、実リポジトリの過去コミット（PR #52・PR #37の両親）に対してスクリプト全体を実行し、
  当時のコンフリクトが再現することを手動で確認する**（合成フィクスチャだけで完了としない）

## 3. 【実装】`.claude/skills/resolve-conflict/SKILL.md`

構成: 呼び出しタイミング／絶対ルール／Step 1-7（検知・ユーザー確認・マージ開始・類型別解消・
検証・コミット・報告）／想定される失敗と対処／詳細ルールへのポインタ。

類型は過去4件の実績から抽出する。

| 類型 | 内容 | 解消ルール |
|---|---|---|
| A | DDR番号の衝突（最頻） | defaultブランチ側を正とし作業ブランチ側を繰り下げ。改番対象はファイル名・frontmatter・見出し・README一覧・他ファイルからの参照 |
| B | Git管理外化した生成物の deleted by us | 管理外にした側を採用（`git rm --cached`） |
| C | 同じドキュメントの近接行 | 両方残して統合。片方を捨てない |
| D | spec/DDRの過去changelog | 時系列順に両方残す。過去エントリは書き換えない |
| E | コード上の競合 | `AskUserQuestion` で人間の判断を仰ぐ |

## 4. 【AIアセット反映】flow-idの繰り下げ

`.claude/skills/issue-mr-flow/SKILL.md` にflow-id 5-2を新設し、旧5-2→5-3・旧5-3→5-4へ繰り下げる
（39→40ステップ）。flow-idを参照している以下も合わせて更新する。

- `.claude/skills/commit/SKILL.md`（frontmatterのdescriptionと本文の2箇所）
- `.claude/rules/git-workflow.md`
- `.claude/rules/docs-workflow.md`（ステップ数も）
- `.claude/docs/spec/issue-mr-workflow.md`（ステップ数2箇所）

`.claude/scripts/src/update-handoff-progress.sh` の `LOOP_RANGES` はフェーズ2〜4のみを扱うため
**変更不要**（フェーズ5にループ範囲は無い）。

## 5. 【設計反映】

- `.claude/docs/spec/check-base-conflicts.md` を新規作成（背景・仕様・実装上の注意・影響範囲・未決定事項）
- `.claude/docs/ddr/0029-…md` を新規作成（決定7点・却下案5点）
- `.claude/docs/README.md` のspec一覧・DDR一覧へ追加
- `.claude/docs/spec/issue-mr-workflow.md` の「影響範囲」へissue #46のエントリを追記
- `.gitignore` の `index.jsonl` 除外理由コメントが参照するDDR番号を `0024` → `0025` へ修正
  （issue #36の改番時の更新漏れ。本issueが対象とする問題の実例なので、スキルの類型Aの説明にも引用する）
- `index.md` / `.claude/skills/apply-mr-workflow-to-project/SKILL.md` のスキル・スクリプト一覧へ追加

## 検証

1. `bash -n` で新規・変更した `.sh` の構文チェック
2. `tests/test_*.sh` を全件実行（既存テストのデグレが無いこと）
3. 過去コミットに対する検知の再現確認（上記2の手動確認）
4. `ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d` で番号重複が無いこと
5. `bash .claude/scripts/src/check-base-conflicts.sh` が現ブランチで `hasConflict: false` を返すこと
6. `bash .claude/scripts/src/extract-frontmatter.sh .` でfrontmatterインデックスを再生成できること
