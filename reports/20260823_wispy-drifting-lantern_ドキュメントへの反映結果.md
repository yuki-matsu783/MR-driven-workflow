---
title: 反映結果 — stateのwip移設をドキュメントへ反映した
type: report
description: .claude/state を wip/state へ移した結果を rules・spec・DDRへ反映し、作業中に判明した2つの罠をAIアセットへ追記した結果
tags: [report, workflow, documentation]
keywords: [設計反映, AIアセット反映, DDR, i0184-01, directory-structure, git-workflow, shell-script-style, changelog, wip, state]
---

# 反映結果 — stateのwip移設をドキュメントへ反映した

- issue: #184 / PR: #190
- 全体作業計画: `plans/wispy-drifting-lantern.md`
- 個別反映計画: `plans/【設計反映】【AIアセット反映】stateのwip移設をドキュメントへ反映する.md`
- フェーズ4〈反映〉 flow-id 4-6 / push3 / 2026-08-23

## サマリ（結論の一覧）

| # | やったこと | 結論 | 根拠の性質 |
|---|---|---|---|
| 1 | 設計反映（rules 1本・spec 3本） | 現在の状態を説明する記述だけを `wip/state/` へ更新 | 実装の確認 |
| 2 | DDR `i0184-01` の新規作成 | 移設先・`/wip/` で無視しない判断・旧パスignoreを残す判断・自動移行を書かない判断の4つを記録 | 実装の確認 |
| 3 | DDR一覧の再生成 | `generate-ddr-list.sh` が86件で更新（`i0184-01` の行が入った） | 実測 |
| 4 | 過去changelog・DDR本文の保全 | **DDRの削除行0件**、spec の issue #13 changelog（2301〜2302行目）が無変更のまま残存 | 実測 |
| 5 | AIアセット反映（洗い出し手順1〜4） | 起点2件、いずれも **(c)「アセットはあったが、その罠が書かれていなかった」** と判定し、既存ルール2本へ追記 | ドキュメントの読解＋grep |
| 6 | usecase文書への影響 | 9本を確認し、`.claude/state/` に触れているものは**0件** | 実測 |
| 7 | 参照切れ検査 | `check-doc-references.sh` が参照切れ0件（候補247件） | 実測 |

## 実施した内容と結果

### 1. 設計反映

| ファイル | 変更内容 |
|---|---|
| `.claude/rules/directory-structure.md` | ツリー直後の注記（`reports/`・`usage/`・`wip/state/`）と、`.claude/state/` の説明段落を全面的に書き換え。内訳（review-links / adversarial-review）を明示し、移設の理由・移行用の除外行・「`/wip/` へ広げてはいけない」を追記 |
| `.claude/docs/spec/issue-mr-workflow.md` | 「/compact実施の呼びかけ」節（**現在の仕様**）を `wip/state/review-links/` へ。**過去changelog（2301〜2302行目）は触らず**、末尾へ issue #184 の**新規エントリ**を追加 |
| `.claude/docs/spec/adversarial-review.md` | 状態ファイルのパスを `wip/state/adversarial-review/` へ。旧パスだった事実とDDR参照を1文添えた |
| `.claude/docs/spec/sync-gemini-assets.md` | 除外対象の例示を `.claude/settings.local.json` へ差し替え、ローカル状態が列挙範囲に入らなくなったことを明記 |

いずれも**現在の状態を説明する節のみ**を対象にし、一括 `sed` は使っていない。

### 2. DDR `i0184-01`

`.claude/docs/ddr/i0184-01-ワークフローのローカル作業状態はwip配下へ移し旧パスのignoreを移行用に残す.md`
を新規作成し、次の4つの判断とそれぞれの却下案（計6件）を記録した。

1. 移設先を `wip/state/` にした（`.claude/` を配る資産だけにする）
2. `.gitignore` のパターンを `/wip/` へ広げない（#165 の追跡対象が無視される）
3. 旧パス `/.claude/state/` の除外行を移行用に残す（既存の残骸が追跡対象に現れる）
4. 旧→新の自動移行コードを書かない（両ファイルとも「無ければ初回」のフォールバックを持つ）

`bash .claude/scripts/src/generate-ddr-list.sh` を実行し、`.claude/docs/README.md` の差分
（1行追加）を同じコミットへ含めた。

### 3. AIアセット反映（洗い出しの結果）

**手順1（起点の列挙）: 2件。** いずれも `worklog/…push2.md` の「ダメだったこと」と
`reports/…移設.md` の「想定と異なった点」から。MRのレビューコメントは、このセッションでは
往復が発生していないため入力に含まれない。

**手順2（4類型への分類）: 2件とも (c)。**

| # | 起点 | 既存の記述 | 判定 |
|---|---|---|---|
| 1 | `.gitignore` のパターン移設で旧パスの残骸が `git status` に現れる | `git-workflow.md`「コミット運用」に**副産物と `.gitignore` の扱い**はあるが、**既存パターンを移設したときの旧パス**は無い | (c) 追記 |
| 2 | テストのフィクスチャ差し替えで検証経路から外れ空振りになる | `shell-script-style.md:923` に「異常が無ければ何も出ない形の検出は…常に成功する」という**同根**の記述はあるが、扱っているのは**静的検出のパターン**であり、フィクスチャの話は無い | (c) 追記 |

**手順3（痕跡の確認）: 段階2で両件とも確定。** (c) なので再現性の証拠は要求しないが、
「その罠を扱った記述が本当に無いこと」の確認は必要なため段階2を実施した。

```
bash .claude/scripts/src/search-frontmatter.sh --text 'gitignore' --format count
  → matched=9 total=159
grep -rn '残骸|旧パス' .claude/docs .claude/rules
  → 該当は DDR i0039-01 の1件（無関係の文脈）と、git status --porcelain の改名エントリの話のみ
grep -rn '空振り|常に成功' .claude/docs .claude/rules
  → hookの前置フィルタ・配布の空振りエントリ・shell-script-style.md:923（静的検出）
```

段階3（直近10件のマージ済みPR＋DDR一覧）へは進んでいない。段階3は「(a) として反映してよいか」を
決めるための段であり、段階2で (c) が確定したためである。

**手順4（反映先の形態）: 既存節への追記2件。** 常時読込のアセットを新規に増やしていない。

| ファイル | 追記した内容 |
|---|---|
| `.claude/rules/git-workflow.md`「コミット運用」 | `.gitignore` の既存パターンを移すときは旧パスの行を残すか必ず判断する／残すなら削除条件をコメントに書く／`dist-layers.json` の `local` エントリも同時に足す／移す先のパターンを必要より広く取らない |
| `.claude/rules/shell-script-style.md`「テスト」 | フィクスチャを別パスへ差し替えるときは検証経路に乗っているか確かめる／判定は「意図的に壊したときテストが落ちるか」で行う／`test_sync_gemini_assets.sh` T8 の実例 |

### 4. 実装反映

**該当なし。** フェーズ3のレビュー往復で持ち越した不具合は無い。作業中に判明した
「旧パスの除外行」はフェーズ3の中で解消済みである。

### 5. 検証（実行したコマンドと結果）

```
bash .claude/scripts/src/generate-ddr-list.sh
  → DDR一覧を更新しました（86件）: .claude/docs/README.md
  → README に i0184-01 の行（185行目）

bash .claude/scripts/src/check-doc-references.sh
  → 走査ファイル数=348 / 候補数=247 / 参照切れ数=0

git diff 4be448a -- .claude/docs/ddr/ | grep -c '^-[^-]'
  → 0（既存DDR本文に削除行が1行も無い）

grep -n '`.claude/state/review-links/`に前回pushのHEAD SHAを保存' .claude/docs/spec/issue-mr-workflow.md
  → 2301行目（issue #13 の過去changelogが無変更のまま残っている）

bash .claude/scripts/src/extract-frontmatter.sh .
  → files=161 built=9 reused=152 failed=0 skipped=0
```

## 確かめられなかったこと

- **追記した2つのルールが、次に同じ状況へ置かれたAIに実際に効くか。** ルールは読ませる形の
  アセットであり、効いたかどうかは次に同型の作業が起きるまで分からない。
- **git bash（Windows）実機での動作**（フェーズ3の作業結果レポートと同じ理由）。
- **`.claude/VERSION` を上げるべきか。** 判断は人間に委ねる
  （`.claude/docs/spec/distribution-assets.md`「人間の判断で据え置くことがある」）。この反映では
  据え置いている。

## 想定と異なった点

- **`.claude/docs/usecase/` は0件だった。** 9本すべてを確認したが、`.claude/state/` に触れている
  ものは無く（`gitignore` の唯一の言及は `index.jsonl` の話）、更新は発生しなかった。
  flow-id 4-6 が求める「usecase文書への影響の確認」自体は実施している。

## 残課題

- **flow-id 5-3**: `.gemini/` の変換同期（`.claude/` 側を変更したため必須）。
- **人間のレビュー往復**（4-3/4-4・4-8/4-9）は、このセッションでは実施できていない。
