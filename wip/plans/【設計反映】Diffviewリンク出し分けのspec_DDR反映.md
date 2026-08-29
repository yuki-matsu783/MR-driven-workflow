---
title: 【設計反映】Diffviewリンク出し分けのspec/DDR反映
type: plan
description: issue #205 フェーズ4の個別反映計画。get_mr_diff_url の4引数化・resolve_mr_number_for_head 新設・複数候補SHA対応をspec「提供関数」表・未決定事項・参照リンクの付与節・影響範囲changelogへ反映し、新規DDRを起票してmcp-fallback.mdを更新する
tags: [plan, phase4, issue-mr-flow, spec, ddr]
keywords: [get_mr_diff_url, resolve_mr_number_for_head, refs/pull, 提供関数表, 未決定事項, DDR, mcp-fallback, 影響範囲, 参照リンクの付与]
---

# 【設計反映】Diffviewリンク出し分けのspec/DDR反映

対象: issue #205「defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する」フェーズ4（反映）。
全体作業計画: `wip/plans/diffview-link-switchover.md`
実装結果: `wip/reports/20260824_diffview-link-switchover_実装結果.md`
調査結果: `wip/reports/20260824_diffview-link-switchover_調査結果.md`

## 前提（合意状況）

上位計画（全体作業計画）はflow-id 1-4でこのセッションが作成し、人間の合意（flow-id 1-5）は
未取得（非対話的実行環境のため）。フェーズ2・3はいずれも人間レビューの代わりに敵対的レビュー
（各フェーズ2回ずつ）を実行し、指摘へ対応・返信済み。本計画（フェーズ4）も同じ扱いとし、
作成直後に敵対的レビューを1回実行する（計画時レビュー）。

**改訂第2版**: 計画時レビュー（フェーズ4・1回目）で12件（major 6 / minor 6）検出され、うち
9件を投稿・全件へ対応した。反映対象を4箇所→7箇所へ拡大し、「検証」「スコープ外」の2節を
新設している（詳細は同一PR上のレビュースレッド9件、および対応する返信を参照）。

## 反映対象（洗い出し）

実装結果・調査結果の両レポート、および反映先spec/rulesの現況照合から、更新が必要な箇所を
洗い出す。**単発の記述変更だけでなく「同じ判断を述べている他所」を横断して洗い出す**
（下記「巻き添えの確認」の手順で機械的に補強する）。

### 1. `.claude/docs/spec/issue-mr-workflow.md`「提供関数」表

| 行 | 現状 | 変更内容 |
|---|---|---|
| `get_mr_diff_url <repoUrl> <baseBranch> <headBranch>` | 3引数、常にCompareを返すと読める記述 | シグネチャを4引数（`[<mrUrl>]`）へ。説明へ「`mrUrl`が非空ならDiffview（GitHubは`/files`、GitLabは`/diffs`）、空ならCompare」を追記。issue #205を追記 |
| （新規行） `resolve_mr_number_for_head <sha>...` | 存在しない | 新設。「候補SHAのいずれかに対応するMR/PR番号を、CLIを使わずgit ls-remoteだけで解決する（GitHubのみ。GitLabは空を返す）。解決できなければ空＋終了コード0（呼び出し側はCompareへ縮退）」。GitHub列は`git ls-remote origin 'refs/pull/*/head'`、GitLab列は「未対応（空を返す）」 |

`get_mr_diff_since_url` / `get_diff_anchor_url` は**関数の実装・戻り値とも**変更しない
（調査結果の決定4「`get_mr_diff_since_url`は変更しない」のとおり）。

`get_diff_anchor_base_url` は**関数の実装は不変**だが、呼び出し側（`post-push-compact-prompt.sh`）
が今回から**意図的に `compare_url`（`diff_url` ではない）を渡す**という前提が新たに加わる
（調査結果Q5「分離の残存制約」）。表の当該行の説明へ「差分アンカーの土台は、issue #205後も
`diff_url`ではなく`compare_url`を渡す（GitHubのアンカーが`/files`上で機能するか未検証のため）」
の1文を追記する。関数シグネチャ・戻り値表現は変更しない。

### 2. `.claude/docs/spec/issue-mr-workflow.md`「未決定事項・懸念点」

- **（issue #13）`get_mr_diff_url`/`get_mr_diff_since_url`のURL形式: GitHub側のみブラウザ未検証**
  の項目を更新する。現状の記述はCompare方式を前提に「PR個別のサブタブ形式より安定していると
  考えられる」と書いているが、本issueでDiffview（`/files`）へ出し分ける経路が追加されたため、
  現状に合わせて書き直す。**「ブラウザ未検証」自体は本issueでも解消していない**（この実行環境
  ではブラウザ目視ができないため）ので、未決定事項としては残しつつ、Diffview経路の追加とissue
  #205を追記する形にする（削除はしない。DDRへの記録で判断の変遷を残す方針は調査結果flow-id
  2-6の回答のとおり）。
- 新規の未決定事項として、次の6点を追加する（実装結果「測っていないこと」・「追記」節、および
  調査結果「この環境で確認できなかったこと（フェーズ4でspecへ引き継ぐ）」より。従来の3点に
  加え、計画時レビューで漏れを指摘された3点を追加した）。
  1. `git ls-remote` 呼び出しのgit bash（Windows）実機でのコスト・認証プロンプト対策の実効性が
     未検証。
  2. CLI経路（`get_vcs_access_mode`が`cli`）での`resolve_mr_number_for_head`呼び出しブロックの
     素通り（`[ -z "$mr_url" ]`）は、コードを読んだ上での判断であり実機確認ではない。
  3. `wip/state/review-links/<branch>.txt`のブランチ名重複衝突（`safe_branch`の記号潰し）による
     `prev_sha`混入リスクは、`git cat-file -e`検証で緩和したが、別ブランチが同じ状態ファイルを
     共有すること自体は解消していない（敵対的レビュー2回目 指摘2への対応で判明）。
  4. **GitHubの差分アンカー（`#diff-<sha256>`）がPRの`/files`上で機能するかは未検証**。
     Compareページ上でのみ実機確認済み（issue #42/#127）で、issue #205はこれに依存しない設計
     （`diff_url`と`compare_url`の分離）を採ったが、確認できれば土台を`/files`へ寄せて残存制約を
     解消できる余地がある。確認が取れるまでは寄せない。
  5. **上記4の帰結として、GitHubでは重点レビュー対象ファイルの差分アンカーリンクがCompare
     ページ上に残る**（issue #205が問題にした「defaultブランチとの差分」1本についてのみ
     Diffviewへ切り替わり、重点ファイルリンクは対象外）。issueの目的はこの1リンクについてのみ
     達成される。
  6. `refs/pull/*/head`のref数が桁で増えた場合の`git ls-remote`所要時間（本環境は99件までしか
     計測していない）、fork元PR・オフライン時の挙動（いずれもCompareへ縮退する見立てだが未検証）、
     GitLabの`refs/merge-requests/<n>/head`相当（実機検証ができず対象外とした）、SSH remoteで
     `resolve_mr_number_for_head`が実際に起動しないことの実環境未確認、の4点はいずれも「引き継ぐ」
     とレポートが明記した項目である。1つの未決定事項へ列挙する形でまとめて残す。

### 3. 新規DDR `i0205-01`

意思決定の骨子（DDRとして残す価値がある「検討したが却下した案」および「過去の却下判断との関係」を
含む）:

1. **`<mrUrl>/files`（GitHub）・`<mrUrl>/diffs`（GitLab）というURL形式を、未検証のまま採用した
   根拠（Q1）**。DDR `i0013-01`/`i0044-01`は、当時「UIの構造に対する推測でURLのsuffixを付け
   足す」実装を**ブラウザ確認ができない**という理由で却下し、Compare方式（issue以前から存在する
   標準機能）へ変更した。本issueでは同じ確認不能の制約が続いたまま`/files`・`/diffs`を採用して
   いるが、根拠は「推測」ではなく**issue #205の起票者（リポジトリ所有者）がissue本文で明示的に
   指定したURL形式**であり、GitHub/GitLabの一般的な仕様として広く知られる形式でもある。それでも
   ブラウザでの実機確認は取れていないため、確度は「未検証」のまま残ることを明記する。
2. **DDR `i0013-01`との関係——`superseded`にはしない（Q2）**。`i0013-01`はCompare方式の採用と
   `wip/state/review-links/`によるSHA保持の両方を決めているが、本issueが変更したのは前者の一部
   （「defaultブランチとの差分」1リンクのみ）である。`get_mr_diff_since_url`（前回pushとの差分）
   はCompare方式のまま変更しておらず、`i0013-01`の判断は生き続けている。したがって`i0013-01`の
   frontmatterは変更せず（`status`は付与しない）、`i0205-01`は「部分的な変更」として独立に記録
   する。
3. **`get_mr_diff_url`を4引数の純粋関数に保つ設計**（第4引数`mrUrl`の有無で出し分け）。
   却下案: `get_mr_diff_url`の内部でMR URL解決まで行う設計 → 純粋関数でなくなり単体テストが
   困難になるため却下。
4. **MCP経路（`gh`/`glab`CLI不在）でのPR番号解決に`git ls-remote origin 'refs/pull/*/head'`を
   採用**。却下案: 案B（`wip/state/`の状態ファイルにPR番号を保存）→ silent staleness
   （黙って古い値を返す）を理由に却下。案C（`HANDOFF.md`のヘッダから読む）→ 表記依存で壊れやすい
   ことを理由に却下。GitLabは`refs/merge-requests/*/head`の実機検証ができず対象外。
5. **一致判定は「一致したPR番号の種類数がちょうど1のときだけ採用」**（`refs/pull/*/head`には
   マージ済み・クローズ済みPRのrefも永続的に残るため、「番号が最大のもの」では誤ったPRを
   選びうる。フェーズ2レビュー2回目で設計変更）。
6. **複数候補SHA（今回push・前回push）を解決関数へ渡す設計**（フェーズ3の実push検証で、
   `refs/pull/<n>/head`の更新がpushに対して遅れることを実際に観測したため追加。この経緯自体を
   DDRの「決定の背景」として記録する価値がある）。
7. **差分アンカーの土台（`compare_url`）とDiffviewリンク（`diff_url`）を分離**（GitHubの差分
   アンカーはCompareページ上でのみ実機確認済みで、PRの`/files`上での動作は未検証のため、土台を
   移すと後退するリスクがあった。上記「未決定事項」4・5と対応）。

### 4. `.claude/skills/issue-mr-flow/references/mcp-fallback.md`への追記

`gh`/`glab` CLI不在時のMCPフォールバック節へ、次の2点を追記する。

- **hookのCLI/MCP経路ごとの挙動差**: `post-push-compact-prompt.sh`のレビュー依頼メッセージが、
  CLI経路では`get_mr_for_branch`が直接MR URLを返すのに対し、MCP経路では`mr_url`が空のときのみ
  `resolve_mr_number_for_head`（`git ls-remote`）を追加で試みる、という表を追加する。
- **MCPツールのbody引数における`*`喪失の既知の落とし穴**（フェーズ2で観測）を、実際に観測した
  ツール（`mcp__github__create_pull_request`のbody引数で`refs/pull/*/head`が`refs/pull//head`に
  なった事象）を主語にして記録する。**`add_comment_to_pending_review`では同種の`*`喪失は観測して
  いない**（同レポートで確認したのは、そちらでは山括弧による切り捨てが起きなかったことである）。
  観測したツールと、同種の無言の本文改変が他のbody引数でも起こりうる旨を分けて書く。あわせて
  「Git管理下のファイルへは影響しない」（本文の反映先はファイル書き込みであってMCPツールの
  body引数ではない）という根拠を、この追記自体の中に明記する（`wip/reports/`側には該当記述が
  無いため、この追記が唯一の記録先になる）。

### 5. `.claude/docs/spec/issue-mr-workflow.md`「参照リンクの付与（issue #13）」節の更新

1613〜1632行が今回の変更で部分的に偽になる。次の2点を更新する。

- 1617行「常に含める: MRへのリンク（`get_mr_for_branch`の`url`）」の直後に、MCP経路では
  `resolve_mr_number_for_head`＋`get_mr_url`で解決したURLが`mr_url`へ入り、同じ行に出る旨を
  追記する（調査結果Q6「解決したPR URLを`mr_url`へ格納する」決定のとおり）。
- 1622〜1632行「URL組み立ての方針（issue #13フォローアップ）」に、issue #205による部分的な
  上書きを追記する。「defaultブランチとの差分」（`get_mr_diff_url`）1リンクに限り、MR/PR URLが
  解決できた場合はCompareではなくDiffview（`/files`・`/diffs`）を返すようになったこと、
  それ以外の3リンク（MRへのリンク自体・前回pushとの差分・重点ファイルの差分アンカー）は
  Compare方式のまま変更していないことを明記し、DDR `i0205-01`への参照を追加する。

### 6. 既存記述の更新（MCP経路でのMRリンク解決に伴う2箇所）

新規追記だけでなく、次の**既存2箇所**を今回の変更に合わせて書き直す（放置すると、同じ内容の
「正」が2つ生まれ片方が古いままになる）。

- `.claude/skills/issue-mr-flow/references/mcp-fallback.md` 108行（§4の表、
  `post-push-compact-prompt.sh`の行）: 「MRリンクだけを『MCPで取得すること』に差し替え」から、
  「`resolve_mr_number_for_head`（`git ls-remote`）で解決を試み、成功すればMRリンク・差分リンクの
  両方に反映する。解決できなければ従来どおり『MCPで取得すること』の指示文とCompareへ縮退する」
  という趣旨へ書き換える。
- `.claude/docs/spec/issue-mr-workflow.md` 979〜980行（「hookの縮退」`post-push-compact-prompt.sh`
  の行）: 同上の趣旨（GitHub MCP経路で解決に成功した場合／失敗してCompareへ縮退する場合の両方）
  へ書き換える。

### 7. `.claude/docs/spec/issue-mr-workflow.md`「影響範囲」への issue #205 changelogエントリ追記

`## 影響範囲`（1911行）配下へ、既存エントリ（`### issue #142` 等）と同じ形式で
`### issue #205（defaultブランチとの差分リンクをPR/MRのDiffviewへ変更する）` を**追記**する
（既存エントリは書き換えない）。含める内容:

- 何を変えたか（`get_mr_diff_url`の4引数化・`resolve_mr_number_for_head`新設・複数候補SHA対応・
  `compare_url`/`diff_url`分離）の概要。
- 「変更したファイル」表（`Provider.sh` / `Github.sh` / `Gitlab.sh` / `post-push-compact-prompt.sh` /
  `test_vcs_provider.sh` / spec本体 / mcp-fallback.md / 新規DDR）。
- 「却下した代替案」（案B・案C・最大番号を採る一致判定・4引数化しない設計）とDDR `i0205-01`への
  参照。
- issueの目的が「defaultブランチとの差分」1リンクについてのみ達成され、重点ファイルリンクは
  対象外である旨（未決定事項4・5と対応する要約）。

## 巻き添えの確認

- spec本文の「提供関数」表は、`get_mr_diff_url`の行**1行だけ**を書き換える（前後の行の書式・
  列幅崩れが起きないよう、既存の行を1行単位でコピーしてから編集する）。
- 「未決定事項・懸念点」の該当項目は、issue #13の項目として**既存の箇条書き構造を保ったまま**
  文言を差し替える（削除・新規追加ではなく更新であることを、diffで確認する）。
- DDR `i0205-01`のファイル名・frontmatterの`title`・本文冒頭の見出しの3箇所は
  `.claude/rules/markdown-frontmatter.md`の書式（`i0205-01. <タイトル>`）に揃える。DDR
  `i0013-01`のfrontmatterは**変更しない**（`status`を付与しない）。
- **反映対象を確定する前に、旧挙動（MCP経路ではMR URLが取れない／差分リンクは常にCompare）を
  述べている記述を横断的に洗い出す。** `grep -rn` で `MCP` `CLI不在` `Compare` `get_mr_diff_url`
  `mr_url` 等を`.claude/docs/spec/` `.claude/skills/issue-mr-flow/references/`
  `.claude/hooks/post-push-compact-prompt.sh` へ横断的にかけ、ヒットした行が今回の変更後も
  正しいかを1件ずつ確認する（本レビューで見つかった `spec 979-980行` `mcp-fallback 108行` は
  この洗い出しで拾えたはずのものである）。`.claude/hooks/post-push-compact-prompt.sh` の
  87〜91行のコメント（「PR/MRのURLは`gh`/`glab`由来」「CLI不在時は…`mr_url`に空文字列を渡す」）
  も対象に含め、コードコメントとして偽になっていれば直す（spec/DDRへの反映ではなくコード側の
  コメント修正であり、上記「反映対象」7項目とは別枠の作業として扱う）。

## スコープ外（この計画で決めないこと）

- **`get_diff_anchor_base_url`の土台を`compare_url`から`diff_url`へ寄せる判断**: GitHubの
  アンカーが`/files`上で機能すると確認できた場合の設計変更。未決定事項4・5として記録するのみで、
  本計画では判断しない。確認・判断はissueが立てば別途行う。
- **GitLab MCP経路での`resolve_mr_number_for_head`相当の対応**: 調査結果・DDR骨子1で「GitLabは
  `refs/merge-requests/*/head`の実機検証ができず対象外」とした判断を維持する。GitLab環境での
  検証が可能になった時点で別issueとして起票する。
- **`.claude/hooks/post-push-compact-prompt.sh` 87〜91行のコードコメント修正**: 上記「巻き添えの
  確認」で偽になっていると判明した場合の修正自体は行うが、それ以外のコメント文言の見直し・
  リファクタリングは本計画のスコープに含めない。
- **`.gemini/`への変換同期**: flow-id 5-3で行う。本計画（フェーズ4）の完了条件には含めない。

## 検証

反映漏れ（本レビューで挙げたような欠落）を検出できるよう、反映対象ごとに**変更前は0件・
変更後は1件以上**になる固有語のgrepを検証節として置く。**着手前（変更前のツリー）で実行し、
期待どおり0件であることを確認してから実装へ進む。**

```bash
# 反映対象1: 提供関数表にget_mr_diff_urlの4引数化（[<mrUrl>]表記）があるか
grep -c '\[<mrUrl>\]' .claude/docs/spec/issue-mr-workflow.md
# 反映対象1: resolve_mr_number_for_head の行があるか
grep -c 'resolve_mr_number_for_head' .claude/docs/spec/issue-mr-workflow.md
# 反映対象2: 未決定事項にissue #205への言及があるか
grep -c 'issue #205' .claude/docs/spec/issue-mr-workflow.md
# 反映対象3: DDR i0205-01が存在するか
ls .claude/docs/ddr/ | grep -c '^i0205-01'
# 反映対象4・6: mcp-fallback.mdにresolve_mr_number_for_headへの言及があるか
grep -c 'resolve_mr_number_for_head' .claude/skills/issue-mr-flow/references/mcp-fallback.md
# 反映対象5: 「参照リンクの付与」節にDiffviewへの言及があるか
sed -n '1610,1635p' .claude/docs/spec/issue-mr-workflow.md | grep -c 'Diffview'
# 反映対象7: 影響範囲にissue #205のエントリがあるか
grep -c '^### issue #205' .claude/docs/spec/issue-mr-workflow.md
```

（数える語は見出し・目次に使われる構造語を避け、変更対象の固有名詞・issue番号を使う。実行結果は
`wip/reports/`側の反映結果へ「変更前0件→変更後1件以上」の形で記録する。）

## 完了条件

1. spec「提供関数」表の`get_mr_diff_url`行が4引数版に、`resolve_mr_number_for_head`の新規行が
   追加されている。`get_diff_anchor_base_url`行に`compare_url`を渡す旨の1文が追記されている。
2. 「未決定事項・懸念点」のissue #13項目が更新され、新規6項目が追加されている。
3. DDR `i0205-01`が作成され、`bash .claude/scripts/src/generate-ddr-list.sh`実行後に
   `.claude/docs/README.md`のDDR一覧へ反映されている。DDR `i0013-01`のfrontmatterは変更されて
   いない。
4. `references/mcp-fallback.md`へ、上記「反映対象」節4の2点（hookのCLI/MCP経路ごとの挙動差の表、
   および`*`喪失の落とし穴の記録）が**両方とも**追記されている。
5. `references/mcp-fallback.md` 108行・spec 979〜980行の既存記述が、MCP経路での解決成功／
   失敗の両方を反映する内容へ書き換わっている（上記「反映対象」節6）。
6. spec「参照リンクの付与（issue #13）」節（1613〜1632行）が、MRリンクの解決経路追加と
   `get_mr_diff_url`のDiffview出し分けを反映し、DDR `i0205-01`を参照している（上記「反映対象」
   節5）。
7. spec「影響範囲」へ`### issue #205（…）`エントリが追記され、既存エントリは1バイトも
   変更されていない（上記「反映対象」節7）。
8. `bash .claude/scripts/src/check-doc-references.sh`を実行し、参照切れが無いことを確認する。
9. 既存の単体テスト21ファイルが全件 `failures=0` のまま（spec/DDR/rules変更はロジックに影響
   しないため、原則ノーオペと見込まれるが、上記「検証」節のgrepで反映漏れが無いことを機械的に
   確認した上で、念のため実行して確認する）。
