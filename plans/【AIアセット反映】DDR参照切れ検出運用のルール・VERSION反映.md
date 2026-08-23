---
title: 【AIアセット反映】DDR参照切れ検出運用のルール・VERSION反映
type: plan
description: issue #171の実装過程で発見したロケール依存の正規表現マッチ罠とgrep一括抽出の性能実測を.claude/rules/shell-script-style.mdへ反映し、新規配布アセットに対する.claude/VERSION増分を人間へ提案する個別反映計画
tags: [gitignore, ddr, doc-references, issue-171, ai-asset]
keywords: [shell-script-style, ロケール, POSIX, ブラケット式, grep, VERSION増分, AIアセット反映]
---

# 【AIアセット反映】DDR参照切れ検出運用のルール・VERSION反映（issue #171）

## 前提（合意状況）

- 上位の計画: `plans/sequential-purring-tulip.md`（全体作業計画、flow-id 1-5で合意）。
- 兄弟計画: `plans/【設計反映】DDR参照切れ検出の意思決定記録.md`（同じくフェーズ4、
  flow-id 4-1）。DDR・spec新設を扱う。本計画はそれとは評価軸が異なる
  「ルール・VERSIONへの反映」のみを扱う（`.claude/skills/issue-mr-flow/SKILL.md`
  「種別を複数併記する場合／分ける場合」により分離。詳細な経緯・訂正点は兄弟計画側の
  「v2での主な訂正点」を参照）。
- 反映元の事実: `.claude/scripts/src/check-doc-references.sh`の実装（flow-id 3-6、
  2回目の敵対的レビュー対応）で実機発見した2件の知見。issue #171・PR #177のコミット
  `e51da6f`のコミットメッセージ・変更内容が根拠。

## この計画で何をするか

1. **ロケール依存の正規表現マッチ罠**を`.claude/rules/shell-script-style.md`へ追記する。
2. **grepへの一括委譲が有利になるケースの実測**を、同ファイルの「外部プロセス起動のコスト」
   節へ補足として追記する（既存規約「ループ内で外部コマンドを呼ばない」と矛盾しない形で
   位置づける）。
3. `.claude/VERSION`の増分を**提案**する（実際の書き換えは行わない。下記「方針」参照）。

## 変更対象

- `.claude/rules/shell-script-style.md`（追記のみ。既存記述は変更しない）
- `.claude/VERSION`（**変更しない**。提案のみをHANDOFF・最終統括レポートへ残す）

## 方針

### ロケール依存の正規表現マッチ罠（追記内容）

`.claude/rules/shell-script-style.md`「文字コード」節の末尾に新しい箇条書きを追加する。

> **POSIX/`LANG`未設定のロケールでは、POSIX ERE のブラケット式（`[...]`）へ多バイト文字を
> 直接含めると、`grep -E`・bashの`[[ =~ ]]`のいずれも、その行がマッチしないだけでなく
> **パターン全体が一致しなくなることがある**（issue #171で実機確認: `.gitignore`のDDR参照
> 検出スクリプトで、全角句読点1文字をブラケット式の終端文字クラスへ追加したところ、
> リポジトリ全体37,411行に対する候補抽出が121件から0件へ落ちた）。`LC_ALL=C.UTF-8`を
> 明示すれば再現しないが、git bash/Windows配布先ではロケールを制御できないため、**正規表現
> 自体には多バイト文字を含めず、抽出後の文字列をASCII構造（固定の英数字プレフィックスの
> 再出現位置等）だけで判定する後処理で対応する**（実装例:
> `.claude/scripts/src/check-doc-references.sh`の`split_concatenated_candidates_to_reply`）。

**確認方法**: この追記自体は新しい罠の記録であり、追記によって既存の動作を変えない
（ドキュメントのみの変更のため「変えないはずのものが変わっていないか」の検証は不要）。

### grep一括抽出が有利になるケースの実測（追記内容）

同ファイル「外部プロセス起動のコスト」節へ、既存の「ループ内で外部コマンドを呼ばない」
原則の**適用範囲の補足**として追加する（原則を変更するのではなく、原則が指す「外部コマンド」
が「ループの中で複数回呼ぶ」ケースを指しており、「まとめて1回だけ呼ぶ」ケースとは区別する
ことを明確化する）。

> **大量データの走査は、bash単独ループより`grep`等への一括委譲が有利な場合がある。**
> issue #171の検出スクリプトで、リポジトリ全体約37,000行に対する正規表現マッチを
> (a) `git ls-files`で得た各ファイルをbashの`while read`ループ＋`[[ =~ ]]`で1行ずつ判定する
> 方式と、(b) 全対象ファイルを`grep -nHoE`へ1回で渡す方式とで実測比較したところ、
> (a) 5.2秒 → (b) 0.96秒だった。**これは上記「ループ内で外部コマンドを呼ばない」の否定では
> ない。** (b) は`grep`を1回だけ呼びbashのループ自体を無くす設計であり、`grep`をファイルごと
> ・行ごとに呼び直す設計（禁止対象）とは異なる。目安: 判定対象の総行数が数万行を超える場合は、
> ループ＋bash内蔵正規表現よりも一括grepを先に検討する。

### `.claude/VERSION`の増分提案

- `.claude/docs/spec/distribution-assets.md`「`.claude/VERSION`」は、**増分の決め方は
  AIエージェントが提案し人間が決める**（AIが独断で上げない）と定めている。非対話セッション
  ではこの人間判断を得られないため、**本計画では`.claude/VERSION`ファイル自体を書き換えない**。
- **提案内容**: MINOR増分（`0.2.0` → `0.3.0`系）。理由は、配布対象アセット
  （`.claude/scripts/src/check-doc-references.sh`、`.claude/scripts/test/
  test_check_doc_references.sh`、および本計画で新設する
  `.claude/docs/spec/check-doc-references.md`）を新設したため（同specの目安表で
  「資産の追加・フローの拡張」＝MINORに該当）。
- **提案の伝達方法**: 最終統括レポート（flow-id 5-3）とHANDOFF.mdの「判断を迷った内容」に
  この提案を明記し、マージ前にユーザーへ確認する。人間が承認した場合、承認後に別途
  `.claude/VERSION`を書き換える（この計画のスコープには含めない）。人間が「今回は据え置く」
  と判断した場合は、`.claude/docs/spec/distribution-assets.md`「据え置く場合は、そのissueの
  specのchangelogへ据え置いた事実を残す」に従い、`.claude/docs/spec/check-doc-references.md`
  のchangelog相当の記述（新設spec自体がissue #171の変更履歴を持つため、そこに1行残す）へ
  追記する。

## やらないこと（スコープ外）

- `.claude/VERSION`ファイル自体の書き換え（上記「方針」参照。人間の承認後に行う）。
- DDR・新規specの作成（`plans/【設計反映】DDR参照切れ検出の意思決定記録.md`で扱う）。
- `.claude/skills/`・`CLAUDE.md`・`AGENTS.md`への反映（今回の作業で気づいた不備は無いと
  判断。ロケール罠・性能実測はいずれも`.claude/rules/shell-script-style.md`が担う領域であり、
  スキル・エージェント運用ルールの不備ではないため）。

## 検証（この反映が完了したと言える条件）

```bash
bash -n /dev/null   # 対象がmarkdownのみのため構文チェック不要。目視確認のみ
grep -n "ロケール\|POSIX ERE" .claude/rules/shell-script-style.md
grep -n "grep.*一括委譲\|大量データの走査" .claude/rules/shell-script-style.md
git diff --stat "$(git merge-base origin/main HEAD)" -- .claude/rules/shell-script-style.md
```

- 追記した2箇所が、それぞれ「文字コード」節・「外部プロセス起動のコスト」節の**既存記述を
  変更せず末尾へ追加**する形になっていること（既存規約の骨子を壊していないことを、
  追記前後の`diff`で確認する）。
- `.claude/VERSION`が変更されていないこと（`git diff -- .claude/VERSION`が空であること）。
- VERSION増分の提案が、最終統括レポートまたはHANDOFF.mdの「判断を迷った内容」のいずれかに
  明記されていること。
