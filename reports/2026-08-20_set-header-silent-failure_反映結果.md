---
title: 反映結果 — set-headerの失敗検知とヘッダ表記のspec/DDR/AIアセットへの反映
type: report
description: issue #66の反映結果。spec 2件・DDR i0066-01・rules/SKILL.md/REVIEW-POINTS.mdへの反映と、敵対的レビュー指摘への対応
tags: [report, update-handoff-progress, spec, ddr]
keywords: [設計反映, AIアセット反映, i0066-01, generate-ddr-list, 敵対的レビュー, 非互換, 移行手順]
---

# 反映結果 — set-headerの失敗検知とヘッダ表記のspec/DDR/AIアセットへの反映

対象issue: [#66](https://github.com/yuki-matsu783/MR-driven-workflow/issues/66)（flow-id 4-6）
個別反映計画: `plans/【設計反映】〜.md` / `plans/【AIアセット反映】〜.md`

## 敵対的レビュー（フェーズ3・1回目）への対応

`adversarial-review` スキルで findings 7件。うち4件をPR #146 へインラインで投稿し、3件は
確度medium×重大度minorのため報告に留めた。**7件すべてに対応した。**

| # | 指摘 | 重大度/確度 | 対応 |
|---|---|---|---|
| 1 | 見出しが無いHANDOFF.mdでは本文の引用行をヘッダ行として書き換えて成功で返す | major/high | **修正**。ヘッダブロックの打ち切りを見出しの有無に依らないようにした（下記） |
| 2 | 読み取り側（`resolve_loop_rounds_to_reply`）がヘッダブロックへ限定されておらず、引用行から周回数を拾う | minor/high | **修正**。同じ範囲へ限定した |
| 3 | 項目オプションを1つも指定しない `set-header` が、何も検査せず成功して書き戻す | minor/medium | **修正**。`usage` を出して非0で終了する |
| 4 | エラーhintが参照する仕様書の節「HANDOFF.mdのヘッダ行」が存在しない | minor/high | **解消**。本フェーズで同節を新設した |
| 5 | テンプレートを変えたのに `.claude/docs/spec/cleanup-task.md` が旧内容のまま | minor/high | **解消**。同ファイルを更新した |
| 6 | 旧テンプレートのHANDOFF.mdでは `set-header` が必ず失敗するのに移行手順が無い | minor/medium | **解消**。仕様書「影響範囲」へ非互換として明記し、復旧手順を書いた |
| 7 | フロー進捗表が無いまま進んでおり `mark-done` を一度も適用できない | minor/medium | **対応**。41行の進捗表を起こし、単発ステップ11件へ実データで `mark-done` を適用した |

### 指摘1の修正内容（設計の変更）

当初のヘッダブロックは「`## フロー進捗状況` 節の終わりまで。**見出しが無ければファイル全体**」と
していた。これでは、見出しを持たないHANDOFF.mdで「やったこと」節の引用行を書き換えたうえ、
一致件数1で検査も通り**終了コード0で成功を返す**。防ごうとした事故がそのまま残っていた。

**打ち切りを見出しの有無に依らない定義へ変えた。**

> ヘッダブロック = ファイル先頭から、**最初に現れる「`## フロー進捗状況`」以外の `## ` 見出し**の
> 直前まで。`## ` 見出しが1つも無いファイルでは全体。

「限定は条件付きにしない（条件から外れた入力で、防ぎたかった事故が残る）」という一般則として、
`.claude/REVIEW-POINTS.md` へも観点を足した。

### 追加したテスト（73ケース、+9）

見出し無しでの引用行の保護／ヘッダ行が本文にしか無い場合のエラー／`### ` では打ち切らないこと／
引用行から周回数を拾わないこと／項目未指定でのエラー。

## 設計反映

| ファイル | 反映内容 |
|---|---|
| `.claude/docs/spec/update-handoff-progress.md` | **「HANDOFF.mdのヘッダ行」節を新設**（表記の定義＝issueの受け入れ条件3／ヘッダブロックの定義／スクリプト全体の方針）。サブコマンド表の `set-header` のエラー条件を更新。`- 現在のループ:` 行の挿入位置の記述を更新。「制約・設計判断」へ #140 との切り分けを追記。「影響範囲」へ issue #66 のエントリ（**非互換と移行手順を含む**）を追記 |
| `.claude/docs/spec/cleanup-task.md` | `HANDOFF_TEMPLATE` がヘッダ行の雛形6行を持つようになったこと（理由と、表記の定義への参照） |
| `.claude/docs/ddr/i0066-01-HANDOFFのヘッダ表記を1つに定めset-headerは見つからなければ失敗させる.md` | 新規。採用案と却下案4件 |
| `.claude/docs/README.md` | `bash .claude/scripts/src/generate-ddr-list.sh` で再生成（64件。手書きしていない） |

### DDRに書いた却下案

1. **`- Draft PR:` を別名として受け付ける** — 表記のゆらぎを仕様として抱え込み、次の別名で同じ
   判断を繰り返す。
2. **見つからないヘッダ行を自動で挿入する** — 誤記の行を残したまま正しい行が増える
   （`- Draft PR:` と `- PR:` が並ぶ）状態を作る。
3. **issue #140 と1つにまとめる** — 症状は同じでも、#66 は「実装がエラーを返し損ねている不具合」、
   #140 は「インターフェースの意味をどうするかの設計判断」。混ぜるとレビューの評価軸が混ざる。
4. **表記の定義を `.claude/rules/docs-workflow.md` 側に置く** — 表記はスクリプトの探索パターンと
   必ず一致していなければならないため、スクリプトの仕様書から離すと片方だけ更新される。

## AIアセット反映

| ファイル | 反映内容 |
|---|---|
| `.claude/rules/docs-workflow.md` | HANDOFF.md の行へ、ヘッダ行の表記は仕様書「HANDOFF.mdのヘッダ行」が正であることの参照を追加（表記そのものは再掲しない） |
| `.claude/skills/issue-mr-flow/SKILL.md` | `set-header` が失敗しうること、失敗時に6行を置いてから再実行することを追記 |
| `.claude/REVIEW-POINTS.md` | 「スクリプトの作法」へ2観点を追加（対象範囲の限定／見つからなかったことの検知。**書き換え側だけでなく読み取り側にも同じ範囲・検知を適用したか**まで含める） |

### 反映しなかったもの

- `.claude/rules/shell-script-style.md`。今回踏んだのは「探索範囲を限定していない」「一致件数を
  数えていない」という設計上の抜けで、**bash固有の罠ではない**。同ファイルはbash固有の罠を
  集めた場所なので混ぜず、レビュー観点として `.claude/REVIEW-POINTS.md` へ置いた。
- `.claude/agents/issue-mr-resume.md`。`- 現在のループ:` / `- 追従監視:` 行を**読む**だけで、
  表記の確定による変更は要らない。
- `.claude/docs/spec/issue-mr-workflow.md` の `- 追従監視:` に関する記述。今回変更していない。

## HANDOFF.mdでの実データ確認（指摘7への対応）

41行の進捗表を起こし、`update-handoff-progress.sh` を実データに対して通した。

- `mark-done` を単発ステップ11件（1-1/1-2/1-3/1-4/1-6/2-1/2-2/3-1/3-2/4-1/4-2）へ適用し、
  すべて `[x]` になることを確認した。
- ループ範囲（2-3/2-4・2-6〜2-9・3-3/3-4・3-6〜3-9・4-3/4-4・4-6〜4-9）は、人間のレビュー往復を
  待てない非対話セッションのため `[]` のまま残した（`.claude/rules/docs-workflow.md` の規定）。
- `set-header --pr` / `--push-count` も実データで成功している（このHANDOFF.mdはヘッダ6行を
  正しい表記で持つため）。

## 検証

```
bash .claude/scripts/src/generate-ddr-list.sh   # 64件・差分1行（新規DDRの追加のみ）
bash .claude/scripts/src/extract-frontmatter.sh .   # files=121 built=17 reused=104 failed=0 skipped=0
.claude/scripts/test/ の全14スクリプト            # すべて failures=0
  （うち test_update_handoff_progress.sh は 73ケース、test_cleanup_task.sh は 62ケース）
```

point-in-time記録（DDR本文・specの過去changelogエントリ）は書き換えていない。specへは
**新規エントリの追記**のみを行った。
