---
title: 20260823 humming-mapping-pie OTelリスナー機構のAIアセット反映
type: report
description: OTelリスナー機構の実装で得た知見を.claude/rules/へ反映した結果の記録
tags: [otel, telemetry, perl, ai-asset]
keywords: [directory-structure, shell-script-style, Test::More, TAP, AIアセット反映, index.md]
---

# OTelリスナー機構のAIアセット反映（フェーズ4〈反映〉結果・AIアセット反映分）

対象: 全体作業計画 `plans/humming-mapping-pie.md` のフェーズ4。
前提: `plans/【AIアセット反映】OTelリスナー機構のルール反映.md`（個別反映計画）。
設計反映（`reports/20260823_humming-mapping-pie_OTelリスナー機構の設計反映.md`）の完了・
レビュー後に着手した（`docs-workflow.md`の方針）。

## 反映した内容

反映対象の一部は、設計反映レビュー（flow-id 4-6〜4-9・1周目）で指摘された10件・報告のみ7件への
対応の過程で先行して実施済みだった。本ラウンドでは、その先行分と、個別反映計画に残っていた
未着手分をあわせて完了させた。

### `.claude/rules/directory-structure.md`

| 内容 | 実施時点 |
|---|---|
| ディレクトリツリーへ`.claude/hooks/otel/`（`lib/`・`test/`を含む）を追加 | 先行（レビュー指摘対応） |
| 「配置の指針」節へ、`.claude/hooks/`配下の常駐プロセスは単体テストを`.claude/scripts/test/`ではなく自身の`test/`配下に置く旨・出力形式は`passed=N failures=N`規約に合わせなくてよい旨を追記 | 先行（レビュー指摘対応） |
| `usage/`節の説明へ、OTelリスナー機構が振り分け保存する`usage/claude-otel-YYYYMMDD.jsonl`の存在を追記（対応工数レポート状態とは別物であることを明記） | 本ラウンド |

### `.claude/rules/shell-script-style.md`

| 内容 | 実施時点 |
|---|---|
| 「テスト」節へ、`passed=N failures=N`規約はbash対象であり、perl製の常駐プロセス（`.claude/hooks/otel/`等）の単体テストは`Test::More`・TAP形式でよい旨を追記 | 本ラウンド |

### `.claude/docs/spec/shell-scripts.md`（個別反映計画の対象外だが関連して先行実施済み）

「常駐プロセスが必要な場合（perl）」節を新設し、bash/PowerShellの二択方針に「常駐プロセスが
必要な場合はperl（コアモジュールのみ）」という枝を追加した。DDR `i0103-01`から参照される。

### `index.md`

`.claude/hooks/`の説明へ`.claude/hooks/otel/`（OTelリスナー機構、詳細は
`.claude/docs/spec/otel-listener.md`）を追加した。

## やらなかったこと

個別反映計画に記載のとおり、`.claude/rules/ai-command-style.md`への追記は対象外とした
（今回の実装で新たな知見が無いため）。

## 検証結果

- `.claude/rules/directory-structure.md`・`.claude/rules/shell-script-style.md`の該当節を
  読み直し、既存の記述と矛盾しないことを確認した。
- 追記箇所のfrontmatter（`alwaysApply: true`を持つファイルの既存キー配置ルール）に影響する
  変更は無い（本文のみの追記）。
- `bash .claude/scripts/src/extract-frontmatter.sh .`で`failed=0`を確認した。
