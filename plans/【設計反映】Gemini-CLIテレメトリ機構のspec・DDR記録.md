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
| `.claude/docs/spec/sync-gemini-assets.md` | 変更 | (a) `env`行の帰結を訂正、(b) `telemetry`ブロックを固定値で注入する新しい変換挙動（`SETTINGS_JQ_FILTER`内・`GEMINI_OTEL_OUTFILE_REL`定数）を「変換しないトップレベルキー」節とは別に追記 |
| `.claude/docs/spec/issue-mr-workflow.md` | 変更 | 「対応工数レポート」節（記録範囲の列挙）へ、テレメトリ由来の参考値セクションが追加された旨と新規specへのリンクを1行追記 |
| `.claude/docs/spec/distribution-assets.md` | 変更 | 「既知の問題」節の配布gitignore不一致の記述を、フェーズ3で`/usage/`が追加され一部解消したことに合わせて更新 |
| `.claude/rules/directory-structure.md` | 変更 | `usage/`配下の内訳一覧へ`usage/gemini-otel.log`・`usage/state/gemini-otel/cursor.json`（グローバル・ブランチ/セッション非依存）を追記 |
| `.claude/docs/ddr/i0105-01-二重計上回避方式はsemantic-conventions形式のみ採用しレガシー形式とmetricsを除外する.md` | 新規 | 二重計上回避方式（却下案付き） |
| `.claude/docs/ddr/i0105-02-既定有効化は機微情報未確認のため保留する.md` | 新規 | 既定有効化を保留した判断（却下案付き） |
| `.claude/docs/README.md` | 変更（一部生成物） | (a) `generate-ddr-list.sh`実行によるDDR一覧の再生成（生成物）、(b) spec一覧（**手書き**）へ新規spec `gemini-cli-telemetry.md` の行を追加 |
| `.claude/VERSION` | 変更（提案） | 配布対象アセット（`UsageTracking.sh`・`post-push-usage-report.sh`・`sync-gemini-assets.sh`・`install-to-project.sh`）の変更に対する版増分をAIエージェントが提案し、人間が決める（`.claude/docs/spec/distribution-assets.md`「更新のタイミング」）。据え置く場合は据え置いた事実を新規specのchangelogへ残す |

## 方針

1. **新規spec作成**: `otel-listener.md`の見出し構成（背景・目的／仕組み／配置／設定項目／
   出力形式／既知の制限／影響範囲／未決定事項・懸念点）に倣う。`otel-listener.md`が
   Claude Code側（常駐perlリスナー経由）であるのに対し、本機構はGemini CLI側
   （`outfile`への直接書き出し、常駐プロセス無し）という対比を「背景・目的」で明記する。
2. **`sync-gemini-assets.md`の訂正・追記**（置き換え前後を両方示す）:
   - **置き換え前**（`env`行の帰結列、現行文言）: 「Gemini CLI 経路では対応工数の OTel 計測が
     行われない（issue #70 / #103）」
   - **置き換え後**: 「Gemini CLI 経路では、Claude Code由来の`env`ブロックとしてのOTel計測は
     行われない（issue #70 / #103）。ただしissue #105により、`env`変換とは独立した経路
     （`SETTINGS_JQ_FILTER`内の固定注入。詳細は下記追記）で`telemetry`ブロックが別途追加されて
     おり、`enabled: false`固定のため現状は無効」。**`env`キー自体を変換しない判断（理由列）は
     変更しない**（Claude Code固有の`env`注入の話であり、本issueが追加したのは別経路のため）。
   - **追記**: 「変換しないトップレベルキー」節とは別に、「固定値で注入するブロック」という
     新しい節（または既存「変換規則」節への追記）を設け、`telemetry`ブロックが
     `.claude/settings.json`に対応キーを持たない固定注入であること、`GEMINI_OTEL_OUTFILE_REL`
     定数が出力先パスの単一の出所であること、`enabled: false`固定であることを記載する。
3. **DDR i0105-01（二重計上回避方式）**: `toLogRecord`/`toSemanticLogRecord`が同一イベントに
   つき無条件で2回emitされる事実、metricsが10秒間隔で周期exportされる事実を根拠に、
   「semantic conventions形式のみを対象としレガシー形式・metricsは無視する」という設計を採用した
   理由を書く。却下案: (a) 両形式を採用しevent一意キーで重複排除（実装複雑・状態肥大化）、
   (b) レガシー形式のみ採用（属性名がsemantic conventionsほど確認できていない）。
4. **DDR i0105-02（既定有効化の保留）**: 保留の根拠は**機微情報（tool_call引数等）が
   未確認である点1つに絞る**（`logPrompts: false`が制御するのはプロンプト本文のみで、他イベントの
   機微情報を抑制するかは未確認）。配布先`.gitignore`の`/usage/`未整備は、フェーズ2敵対的レビュー
   で発見された時点では根拠の1つだったが、**フェーズ3で`install-to-project.sh`へ
   `/usage/`除外を追加し既に解消済み**であるため、DDR本文には「フェーズ3で解消済みの条件」として
   経緯にのみ触れ、現在の保留理由には含めない。却下案: 配布先`.gitignore`是正と同時に既定ONにする
   （機微情報確認が済むまで見送り）。残る解除条件（実機での機微情報確認）を明記する。
5. **`.claude/docs/README.md`への追加**: (a) DDR一覧はDDR2本追加後に
   `bash .claude/scripts/src/generate-ddr-list.sh`を実行して再生成する（生成物）。(b) **spec一覧は
   手書き**のため、`otel-listener.md`の行に倣って新規spec `gemini-cli-telemetry.md` の行を
   自分で追加する（generate-ddr-list.shはこちらを更新しない）。
6. **`issue-mr-workflow.md`の相互リンク**: 「対応工数レポート」節（記録範囲の列挙）へ、
   「テレメトリ由来の参考値セクションの詳細は`gemini-cli-telemetry.md`を参照」の1行を追記する
   （詳細の正は新規specに置き、こちらはリンクのみに留める）。
7. **`distribution-assets.md`の是正**: 「既知の問題」節の配布gitignore不一致の記述を、
   フェーズ3で`install-to-project.sh`へ`/usage/`除外が追加されたことに合わせて更新する
   （`/usage/`は解消済み、`/.claude/state/`は引き続き未解消、と書き分ける）。
8. **`directory-structure.md`の追記**: `usage/`配下の内訳一覧へ`usage/gemini-otel.log`と
   `usage/state/gemini-otel/cursor.json`を追加し、後者が既存の状態ファイル群（ブランチ別・
   セッション別）とは異なり**ブランチにもセッションにも紐づかないグローバルなカーソル**である
   ことを明記する。
9. **`.claude/VERSION`の増分提案**: 配布対象アセット4本の変更に対し、資産の追加（新規specは
   配布対象外だが、`sync-gemini-assets.sh`・`install-to-project.sh`等は配布対象）を根拠に
   `MINOR`増分を提案する。人間が据え置きを選んだ場合は、その事実を新規spec
   `gemini-cli-telemetry.md`のchangelogへ残す。
10. **恒久ドキュメントからの参照先の限定**: 新規spec・DDR2本の本文からは`reports/`・`plans/`・
    `worklog/`を参照しない（一次情報として本計画が読んだ`reports/`はflow-id 5-5で削除されるため）。
    参照してよいのはissue番号と`.claude/docs/`配下のみ。

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
grep -c 'spec/gemini-cli-telemetry.md' .claude/docs/README.md
ls .claude/docs/ddr/ | sed -E 's/^(i[0-9]{4,}-[0-9]{2}).*/\1/' | sort | uniq -d
git diff --numstat "$(git merge-base origin/main HEAD)" HEAD -- .claude/docs/ddr/
grep -n 'reports/\|plans/\|worklog/' .claude/docs/spec/gemini-cli-telemetry.md .claude/docs/ddr/i0105-*.md
```

- 合格条件: `.claude/docs/README.md`に新規DDR2本の行（`generate-ddr-list.sh`による生成）と、
  新規spec `gemini-cli-telemetry.md` の行（手書き追加）の両方があること
  （`grep -c 'spec/gemini-cli-telemetry.md'`が1以上）。
- DDR識別子の重複が無いこと: `sort | uniq -d`の出力が空であること（ファイル数の一致ではなく
  識別子文字列の一意性を見る）。
- `git merge-base origin/main HEAD`を基点とした**`.claude/docs/ddr/`配下**の削除行が0であること
  （対象を`.claude/`全体ではなく新規DDRを置くディレクトリへ絞る。`.claude/`全体には
  フェーズ3までの正当な削除が既に含まれているため、それらを誤検知しないため）。
- 新規DDR2本の`title`が`i0105-0N. <タイトル>`形式、frontmatterの`type`が`ddr`であること
  （`.claude/rules/markdown-frontmatter.md`「DDRの識別子」）。新規spec・変更specのfrontmatterが
  typeが`spec`の要件を満たしていること（`title`/`description`/`tags`/`keywords`）。
- 新規spec・DDR2本の本文が`reports/`・`plans/`・`worklog/`を参照していないこと（grep結果が0件）。

## issueの受け入れ条件との対応

| # | 受け入れ条件 | 本計画での対応 |
|---|---|---|
| 1 | telemetry設定によりusage/配下へファイルが生成・追記される | **未達（実機未検証）**。人間への実機確認依頼として持ち越す。新規specの「未決定事項」節に明記 |
| 2 | テレメトリ由来の集計値が対応工数レポートへ載り差分が二重計上されない（単体テスト検証） | フェーズ3で実装・単体テスト済みだが、フィクスチャは合成データ（実データ未検証）。新規specへその旨明記 |
| 3 | issue #97実装のセッションログ集計とテレメトリ集計が二重計上にならない | フェーズ3で実装・単体テスト済み。新規specの「二重計上回避」節、DDR i0105-01 |
| 4 | Claude Code側の集計結果・レポート内容が変化せず既存テストが通る | フェーズ3で確認済み（既存全17本`test_*.sh`が`failures=0`） |
| 5 | `.gemini/settings.json`がTelemetrySettingsスキーマに沿っている | フェーズ2で確認済み |
| 6 | `logPrompts`の既定・出力先が`gitignore`対象であることが明記されている | 新規specの「設定項目」節、DDR i0105-02 |
| 7 | 出力先配置がissue #103と整合している、または整合しない理由が記録されている | 新規specの「背景・目的」節（issue #103との対比） |
| 8 | 設計判断がDDRとして記録されている | DDR i0105-01・i0105-02（本計画で記録する判断はこの2本に限る。カーソル方式の耐障害性等は下記「やらないこと」参照） |
| 9 | 仕様がspecに記録されている、実機検証できない範囲は「未検証」と明示されている | 新規spec全体、とくに「未決定事項」節に未検証範囲を明示 |

条件1〜5は上表のとおりフェーズ3までの実装状況をそのまま転記する（本計画では変更しない）。
条件1は現時点で**未達**であり、フェーズ4の反映によって満たされるものではないことに注意する
（人間への実機確認依頼が解決するまで持ち越し）。
