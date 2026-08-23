---
title: 【設計反映】Gemini-CLIテレメトリ機構のspec・DDR記録
type: plan
description: issue #105フェーズ4の個別反映計画。フェーズ2・3で確定した設計判断をspec（新規1本・既存1本更新）とDDR（新規2本）へ反映する
tags: [gemini-cli, telemetry, spec, ddr, issue-105]
keywords: [otel-listener, sync-gemini-assets, 二重計上回避, 既定有効化, generate-ddr-list, prefixFingerprint]
---

# 【設計反映】Gemini-CLIテレメトリ機構のspec・DDR記録

## 前提（合意状況）

- 上位の計画: `plans/squishy-painting-coral.md`（全体作業計画、flow-id 1-5で合意）。
- フェーズ2（調査）・フェーズ3（作業）はいずれも人間レビュー完了まで到達済み（flow-id 2-9・3-9）。
  実装差分はPR #174へpush11（commit 91e2ee5）まで反映され、MR descriptionも最新化済み
  （flow-id 3-10）。
- 本計画が読む一次情報: `reports/20260823_squishy-painting-coral_Gemini-CLIテレメトリ出力形式と
  統合方針の調査結果.md`（フェーズ2）、`reports/20260823_squishy-painting-coral_Gemini-CLI
  テレメトリ集計機構の実装結果.md`（フェーズ3）。
- 依拠する既存実装・DDR: issue #97（`_usage_gemini_fold`系、DDR i0097-01〜05）、issue #103
  （`.claude/hooks/otel/`、`.claude/docs/spec/otel-listener.md`）、issue #70（`.gemini/`は
  `.claude/`からの変換生成物、`.claude/docs/spec/sync-gemini-assets.md`）。

## この計画で何をするか

フェーズ2・3で確定した設計判断のうち、**永続ドキュメント（spec・DDR）へ記録すべきもの**を
反映する。実装コード・テストコードの追加変更は行わない（フェーズ3のレビュー往復ループで
完結済みのため、本計画は「実装反映」ではなく「設計反映」のみ）。

- 新規spec: Gemini CLI公式テレメトリ機構の仕様を1本にまとめる（`otel-listener.md`と対をなす
  ドキュメント）。
- 既存spec更新: `sync-gemini-assets.md`の`env`行が「Gemini CLI 経路では対応工数の OTel 計測が
  行われない」と書いており、本issueで覆った結論のまま放置されている（push11のレビューで
  「specを名指しした時点で誤り」と指摘され、コード側のコメント参照は既に除去済み。spec自体の
  更新はこの計画で行う）。
- DDR新規2本: フェーズ2・3の敵対的レビューで裏取りした判断のうち、却下案・トレードオフを
  伴う2つを記録する（二重計上回避方式、既定有効化を保留した判断）。

## 変更対象

| ファイル | 種別 | 内容 |
|---|---|---|
| `.claude/docs/spec/gemini-cli-telemetry.md` | 新規 | Gemini CLI公式テレメトリ機構の仕様（背景・目的／仕組み／設定項目／出力形式／カーソル方式／既知の制限／影響範囲／未決定事項） |
| `.claude/docs/spec/sync-gemini-assets.md` | 変更 | `env`行（194〜198行付近）の帰結を、issue #105で`telemetry`ブロックが別経路（`SETTINGS_JQ_FILTER`内の固定注入）で追加されたことに合わせて訂正 |
| `.claude/docs/ddr/i0105-01-〜.md` | 新規 | 二重計上回避方式（semantic conventions形式のみ採用しレガシー形式・metricsを除外する判断、却下案） |
| `.claude/docs/ddr/i0105-02-〜.md` | 新規 | 既定有効化を保留した判断（配布先`.gitignore`未整備・機微情報未確認の2条件、却下案） |
| `.claude/docs/README.md` | 変更（生成物） | `generate-ddr-list.sh`実行によるDDR一覧の再生成 |

## 方針

1. **新規spec作成**: `otel-listener.md`の見出し構成（背景・目的／仕組み／配置／設定項目／
   出力形式／既知の制限／影響範囲／未決定事項・懸念点）に倣う。`otel-listener.md`が
   Claude Code側（常駐perlリスナー経由）であるのに対し、本機構はGemini CLI側
   （`outfile`への直接書き出し、常駐プロセス無し）という対比を「背景・目的」で明記する。
2. **`sync-gemini-assets.md`の訂正**: 「Gemini CLI 経路では対応工数の OTel 計測が行われない」
   （帰結列）を、「issue #105により`telemetry`ブロックは`env`変換とは独立した経路
   （`SETTINGS_JQ_FILTER`内の固定注入）で追加された。ただし`enabled: false`固定のため
   現状は無効」という趣旨へ書き換える。**`env`キー自体を変換しない判断（理由列）は変わらない**
   （Claude Code固有の`env`注入の話であり、本issueが追加したのは別経路のため）ため、
   理由列は変更しない。
3. **DDR i0105-01（二重計上回避方式）**: `toLogRecord`/`toSemanticLogRecord`が同一イベントに
   つき無条件で2回emitされる事実、metricsが10秒間隔で周期exportされる事実を根拠に、
   「semantic conventions形式のみを対象としレガシー形式・metricsは無視する」という設計を採用した
   理由を書く。却下案: (a) 両形式を採用しevent一意キーで重複排除（実装複雑・状態肥大化）、
   (b) レガシー形式のみ採用（属性名がsemantic conventionsほど確認できていない）。
4. **DDR i0105-02（既定有効化の保留）**: 配布先の`.gitignore`が`/usage/`を対象にしないまま
   `enabled: true`を配布すると、テレメトリ出力がコミット候補に現れる非対称
   （フェーズ2敵対的レビューで発見）と、`logPrompts: false`がプロンプト本文以外の機微情報
   （tool_call引数等）を抑制するかが未確認である点を根拠に、`enabled: false`固定とし
   有効化手段を本issueのスコープ外とした判断を書く。却下案: 配布先`.gitignore`是正と
   同時に既定ONにする（`install-to-project.sh`側の変更が別リスクを伴うため見送り）。
5. **DDR一覧の再生成**: 2本のDDR追加後に`bash .claude/scripts/src/generate-ddr-list.sh`を実行し、
   差分をこの計画のコミットへ含める。

## やらないこと（スコープ外）

- 実装コード・テストコードの追加変更（フェーズ3で完結済み）。
- `enabled: false`固定配線に対する有効化手段の確立（DDR i0105-02で却下案として記録するのみ）。
- Gemini CLI実機での動作確認（引き続き未実施。specの「未決定事項」節へ引き継ぐ）。
- カーソル方式の耐障害性（`prefixFingerprint`・書き込み前検証等）を個別のDDRとして独立させること
  （spec本文の「出力形式・カーソル方式」節へ実装済みの事実として記述するに留め、却下案を伴う
  独立の意思決定としては扱わない。二重計上回避（i0105-01）と既定有効化（i0105-02）ほど
  トレードオフの分岐点が明確ではないため）。

## 検証

```bash
bash .claude/scripts/src/generate-ddr-list.sh
git diff --stat .claude/docs/README.md
```

- 合格条件: 上記実行後、`.claude/docs/README.md`に新規DDR2本の行が追加されていること。
- DDR識別子の重複が無いこと: `ls .claude/docs/ddr/ | grep -c '^i0105-'` が2であること。
- `git merge-base origin/main HEAD`を基点とした`.claude/`配下の削除行が0であること
  （DDR番号繰り下げ等の誤った書き換えが無いことの確認）。
- 新規spec・変更specのfrontmatterが`.claude/rules/markdown-frontmatter.md`のtype`spec`の
  要件を満たしていること（`title`/`description`/`tags`/`keywords`）。

## issueの受け入れ条件との対応

| # | 受け入れ条件 | 本計画での対応 |
|---|---|---|
| 6 | `logPrompts`の既定・出力先が`gitignore`対象であることが明記されている | 新規specの「設定項目」節、DDR i0105-02 |
| 7 | 既定有効化の可否についての判断が記録されている | DDR i0105-02 |
| 8 | 二重計上回避の設計判断が記録されている | DDR i0105-01、新規specの「出力形式・カーソル方式」節 |
| 9 | issue #103との関係（整合させるか、しない理由）が記録されている | 新規specの「背景・目的」節 |

（条件1〜5はフェーズ3の実装・単体テストで既に満たしている。フェーズ4は永続ドキュメントへの
記録が主眼のため、対応表は永続ドキュメントに関わる条件のみを挙げる。）
