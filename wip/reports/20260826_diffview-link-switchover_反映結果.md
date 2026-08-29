---
title: 反映結果: Diffviewリンク出し分けのspec/DDR反映
type: report
description: issue #205 フェーズ4の反映結果。spec「提供関数」表・未決定事項・参照リンクの付与節・影響範囲changelog・mcp-fallback.mdの更新と新規DDR i0205-01の作成、9つの完了条件の判定
tags: [report, reflection, issue-mr-flow]
keywords: [spec, DDR, 提供関数表, 未決定事項, 参照リンクの付与, 影響範囲, mcp-fallback, i0205-01, 検証grep]
---

# 反映結果: Diffviewリンク出し分けのspec/DDR反映（issue #205 / flow-id 4-6）

- 個別反映計画: `wip/plans/【設計反映】Diffviewリンク出し分けのspec_DDR反映.md`（改訂第2版）
- 実装結果: `wip/reports/20260824_diffview-link-switchover_実装結果.md`
- 調査結果: `wip/reports/20260824_diffview-link-switchover_調査結果.md`
- PR: #206

## 結論（先に3行）

1. **反映対象7箇所すべてを反映した。** spec「提供関数」表・未決定事項・参照リンクの付与節・
   hookの縮退節・影響範囲changelog、新規DDR `i0205-01`、`references/mcp-fallback.md`の2箇所。
2. **反映漏れを機械的に確認した。** 計画の「検証」節が定めた7本のgrepを、着手前（全件0件）と
   反映後（全件1件以上）の両方で実行した。
3. **既存の記述を破壊していない。** `git diff`の削除行はいずれも今回書き換えると決めた行のみで、
   過去のchangelogエントリ・DDR `i0013-01`のfrontmatterは1バイトも変更していない。

## 完了条件の判定

| # | 条件 | 判定 |
|---|---|---|
| 1 | spec「提供関数」表の`get_mr_diff_url`行が4引数版に、`resolve_mr_number_for_head`の新規行が追加されている。`get_diff_anchor_base_url`行に`compare_url`を渡す旨の1文が追記されている | **達成** |
| 2 | 「未決定事項・懸念点」のissue #13項目が更新され、新規6項目が追加されている | **達成**（issue #13項目を更新し、issue #205関連の新規6項目を追加した） |
| 3 | DDR `i0205-01`が作成され、`generate-ddr-list.sh`実行後に`.claude/docs/README.md`のDDR一覧へ反映されている。DDR `i0013-01`のfrontmatterは変更されていない | **達成**（`generate-ddr-list.sh`実行で97件に更新、`i0013-01`は`git diff --stat`で変更0を確認） |
| 4 | `references/mcp-fallback.md`へ、反映対象4の2点（挙動差の表・`*`喪失の落とし穴）が両方とも追記されている | **達成**（§4表の行更新と§2-bへの新項目追加の両方を実施） |
| 5 | `mcp-fallback.md` 108行・spec 979〜980行の既存記述が、MCP経路での解決成功／失敗の両方を反映する内容へ書き換わっている | **達成** |
| 6 | spec「参照リンクの付与（issue #13）」節が、MRリンクの解決経路追加と`get_mr_diff_url`のDiffview出し分けを反映し、DDR `i0205-01`を参照している | **達成**（新設した「MCPフォールバック時のMR/PR URL解決（issue #205）」節を含む） |
| 7 | spec「影響範囲」へ`### issue #205（…）`エントリが追記され、既存エントリは1バイトも変更されていない | **達成**（`git diff`の削除行に既存changelogエントリは含まれない） |
| 8 | `check-doc-references.sh`実行で参照切れが無い | **達成**（参照切れ数=0） |
| 9 | 既存の単体テスト21ファイルが全件`failures=0`のまま | **達成**（`passed=1550 failures=0`、21ファイル） |

## 検証（計画の「検証」節7本を反映前後で実行）

| # | grep | 反映前 | 反映後 |
|---|---|---|---|
| 1a | `grep -c '\[<mrUrl>\]' .claude/docs/spec/issue-mr-workflow.md` | 0 | 1 |
| 1b | `grep -c 'resolve_mr_number_for_head' .claude/docs/spec/issue-mr-workflow.md` | 0 | 15 |
| 2 | `grep -c 'issue #205' .claude/docs/spec/issue-mr-workflow.md` | 0 | 20 |
| 3 | `ls .claude/docs/ddr/ \| grep -c '^i0205-01'` | 0 | 1 |
| 4/6 | `grep -c 'resolve_mr_number_for_head' .claude/skills/issue-mr-flow/references/mcp-fallback.md` | 0 | 1 |
| 5 | `sed -n '1610,1720p' .claude/docs/spec/issue-mr-workflow.md \| grep -c 'Diffview'`（計画時点の1610-1635では収まらず範囲を広げた。理由は下記「計画との差異」） | 0 | 3 |
| 7 | `grep -c '^### issue #205' .claude/docs/spec/issue-mr-workflow.md` | 0 | 1 |

7本すべてで「反映前0件→反映後1件以上」を確認した。反映漏れの検出手段として機能したことを、
実際に反映前ツリー（コミット`6c18df6`時点）で全件0件を確認したうえで示した。

## 計画との差異

- **検証5のgrep範囲を`1610〜1635`から`1610〜1720`へ広げた。** 「参照リンクの付与」節へ新設した
  「MCPフォールバック時のMR/PR URL解決（issue #205）」小節を、既存の「重点レビュー対象ファイルの
  リンク」小節の後（元の節の末尾付近）へ挿入したため、`Diffview`という語の初出位置が計画時点で
  見積もっていた行範囲より後ろへずれた。grep自体の目的（節内にDiffviewへの言及があるか）は
  変わらないため、範囲だけを実態に合わせて広げた。
- 反映内容自体は計画（改訂第2版）どおりで、範囲以外の差異は無い。

## 巻き添えの確認（実施結果）

計画「巻き添えの確認」の横断grep手順を実行した。

```
grep -rn 'MCP\|CLI不在\|Compare\|get_mr_diff_url\|mr_url' \
  .claude/docs/spec/ .claude/skills/issue-mr-flow/references/ \
  .claude/hooks/post-push-compact-prompt.sh
```

該当した記述のうち、今回の変更後も正しいかを確認した結果は次のとおり。

- `spec 979〜980行`・`mcp-fallback.md 108行` — 計画時レビューで指摘され、上記の反映で更新済み。
- `.claude/hooks/post-push-compact-prompt.sh` 87〜91行のコードコメント（「PR/MRのURLは`gh`/`glab`
  由来」「CLI不在時は…`mr_url`に空文字列を渡す」） — **実装（`resolve_mr_number_for_head`の追加）
  により偽になっていることを確認した。** 個別反映計画「スコープ外」節が「偽になっていれば修正
  する」としていたコード側コメントに該当するため、下記「コード側コメントの修正」で対応した
  （spec/DDR反映とは別枠の1コミットとして扱う）。
- その他の該当行（`get_mr_diff_since_url`・`get_diff_anchor_base_url`のCompare関連の記述等）は、
  今回変更していない挙動を述べたものであり、書き換え不要と判断した。

### コード側コメントの修正

`.claude/hooks/post-push-compact-prompt.sh` 87〜91行のコメントを、`resolve_mr_number_for_head`
追加後の実際の挙動（MCP経路でも`resolve_mr_number_for_head`が解決に成功すればMR/PRのURLを
取得できる）に合わせて更新した。仕様上の記述変更ではなくコードコメントの修正のため、この報告と
は別コミットとして扱う（コミットSHAは`次にやること`の実施後にworklog・HANDOFFへ記録する）。
