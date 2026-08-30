---
title: worklog 【設計反映】【AIアセット反映】反映実施（push6・敵対的レビュー）
type: log
description: issue #151 フェーズ4〈反映〉flow-id 4-6の作業実施段（実装後・push前）に対する敵対的レビュー2回目（フェーズ4通算2回目）と、その指摘12件の反映ログ
tags: [worklog, issue-mr-flow, adversarial-review, spec-reflection]
keywords: [flow-id 4-6, 敵対的レビュー, 注入順序, ブランチ絞り, jq例, stale-reference, 影響範囲]
---

# worklog 【設計反映】【AIアセット反映】反映実施（push6・敵対的レビュー）

issue #151（PR #197）フェーズ4〈反映〉flow-id 4-6。push5でリモートへ反映した実装（spec追記・
DDR新設・コード内参照付け替え・AIアセット反映2項目）に対し、作業実施段の敵対的レビュー
（フェーズ4通算2回目、ユーザー指示「作業実施毎に一度」）を実施した。

## レビュー結果

12件の指摘（major/high 4・major/medium 1・minor/high 3・minor/medium 4）。
push5の時点ではまだGitHub上に対象diffが存在した（push5で既にリモートへ反映済み）ため、
インライン投稿も検討したが、フェーズ4の反映系はflow-id 4-7の直後に投稿する運用
（`adversarial-review`スキル「2-a. 対象を決める」）に合わせ、push前にすべて修正してから
まとめてpush・レビュー依頼する方針とした。**12件すべてを検算し、すべて実在する欠陥と確認した
うえで修正した。**

## 指摘と修正

1. **（major/high）spec項目内の注入順序の記述が自己矛盾していた。** 1文目「現在地flow-idと
   参照ファイルの注入に**続けて**」と、2文目「SKILL.md再読み込み指示**より前**」が逆を
   主張していた。`build_work_context`の実装（作業ファイル→次にやること→ユーザー発言→
   SKILL.md再読み込み指示・現在地flow-id参照行の順）を再確認し、正しい順序で書き直した。
   あわせて、この項目を「出力形式」bulletの**前**（注入内容を列挙する並びの中）へ移動した
   （元は出力形式の後ろに差し込まれ、並びが不自然だった）。
2. **（major/high）「母集団の抽出条件（6条件すべて）」にブランチ絞りが含まれておらず、
   実装より狭い条件として読めた。** `UserUtteranceSelect.jq`を再確認し、実際は
   「5条件＋ブランチ絞り（後処理）＋uuid重複除去（後処理）」の構造であることを確認。
   ブランチ絞りのフォールバックしない理由（別ブランチの発言を無断で注入しないため）も
   明記した。あわせてサイズ管理の項に「超過時は直近群の古い側から1件ずつ落とし先頭群は
   落とさない」という実装の挙動を追記した（従来は上限値6,000Bしか書いていなかった）。
3. **（major/high）shell-script-style.mdのjq優先順位「良い例」が、意図とも実コードとも
   逆の値を返していた。** 実測（`jq -n '{counts:[]} | (type == "object") or (has("counts") |
   not)'`）で確認: 良い例から`.counts |`が落ちており、入力全体の型を見ていた。実コード
   （`session-start.sh`の`read_ack_exclusion_state_to_reply`）と同じ
   `((.counts | type) == "object") or (has("counts") | not)`へ差し替え、`{counts:{}}`を
   入力にして悪い例（false・誤り）と良い例（true・正しい）が実際に分岐することを実測した。
   悪い例の「意図」コメントも「countsがobjectでない」→「countsがobject型」（真逆だった）へ
   訂正した。
4. **（major/high）`session-start.sh`のコメントに、flow-id 5-5で削除される個別作業計画
   「出力位置」節への参照が1箇所付け替え漏れしていた。** `build_work_context`内のコメントを
   新設spec項目（+DDR i0151-01）へ揃えた。
5. **（major/high）`session-start-ack-words.txt`のコメントが`wip/reports/`の調査結果レポート
   「問い5」を参照したまま残っていた。** DDR i0151-01「決定」7（`ok`/`OK`除外の根拠を恒久化
   済み）を指す形へ差し替えた。
6. **（major/medium）spec本文が「git bash見積もり約208msで42%」を確定値として書いており、
   DDR側の「未確認事項」（Linux実測からの見積もりで実測ではない）と食い違っていた。**
   spec側にも「208msはLinux実測の単純和であり、git bash実機での換算・実測ではない」旨を
   追記し、DDRの当該節へリンクした。
7. **（minor/medium）specの「影響範囲」節に、既存慣例（issue #67・#115・#17等の
   `### issue #NNN`節）と揃えたissue #151のchangelogエントリが無かった。** 節を新設し、
   新規・変更ファイル一覧と関連issue（#201・#207）を記載した。
8. **（minor/high）isSidechain項目の参照「上記「JSON操作」節参照」が、参照先が別ファイル
   （`.claude/rules/shell-script-style.md`）であることを示していなかった。**
   `.claude/rules/shell-script-style.md`「JSON操作」節参照、へ明示した。
9. **（minor/high）「改行・連続空白は畳む」という記述が、実装（改行前後の空白のみ畳む。
   改行を挟まない連続空白・タブは畳まない）より広かった。** 「改行（とその前後の空白）を
   畳む」へ訂正した。
10. **（minor/medium）`|| true`をパイプライン全体の末尾へ付ける良い例が、grepのマッチ0件
    以外の失敗（他コマンドの失敗・grep自体の実行時エラー）まで一緒に飲み込む形になって
    いた。** `{ grep ... || true; }`でgrepだけを局所的に包む形へ直し、他メンバの失敗は
    pipefailに検知させられることを実測（意図的なgrepの実行時エラーでも`pipefail`配下で
    `outer=0`のまま継続することを確認したうえで、この形の限界——grep自身の終了コード1と2を
    区別しない——も注記した）。
11. **（minor/medium）DDR i0151-01の「未確認事項」節が「将来本DDRのfrontmatterへ反映する」と
    約束していたが、`markdown-frontmatter.md`が定めるfrontmatter更新（`status`/
    `superseded_by`/`note`）のどれにも収まらない内容だった。** 反映先をspec側
    （性能記述の更新、または「未決定事項・懸念点」）に直し、DDRのfrontmatter更新は
    決定自体が置き換わったとき（`status: superseded`）に限る旨を明記した。
12. **（minor/medium）`.claude/rules/directory-structure.md`のディレクトリツリーに、新設した
    `.claude/hooks/session-start-ack-words.txt`が載っていなかった。** `hooks/`配下のツリーへ
    1行追加した。

## 検証

修正後、以下をすべて再実行し合格を確認した。

- `bash -n session-start.sh` / `bash -n test_session_start.sh`
- `bash .claude/scripts/test/test_session_start.sh` → `passed=159 failures=0`（回帰なし）
- `bash .claude/scripts/src/check-doc-references.sh` → 新規の参照切れ0件（既知の1件
  ＝計画ファイル内のプレースホルダのみ、変化なし）
- `bash .claude/scripts/src/extract-frontmatter.sh .` / `generate-ddr-list.sh`
- jq例2件・grep例1件を実行し、記載どおりの値が返ることを確認

## 次にやること

flow-id 4-6完了。commit・push・レビュー依頼（flow-id 4-7）へ進む。
