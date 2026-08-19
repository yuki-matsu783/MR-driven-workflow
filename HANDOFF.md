---
title: HANDOFF
type: handoff
description: セッション間・作業者間の引継ぎメモ（現在地・次回やること等）
tags: [handoff, workflow]
keywords: [フロー進捗, worklog, 引き継ぎ, plan, レビュー]
---

# HANDOFF

<!--
AI⇔AI/AI⇔人間の状況引継ぎメモ。常に「このブランチの現状」を表現する
-->

## フロー進捗状況

- issue: #38（frontmatterのindex.jsonlを横断検索するスキルとスクリプトを追加する）
- ブランチ: `claude/frontmatter-jsonl-search-wp7odz`（ハーネス指定。`feature-<issue番号>-<slug>`
  規則ではない）
- PR: #104 https://github.com/yuki-matsu783/MR-driven-workflow/pull/104（Draft。ユーザーの明示依頼により作成）
- 追従監視: なし（このセッションではPRイベントを購読していない。次セッションは `resume` で取り直す）
- push回数: 2
- 現在のループ: なし

**非対話的なリモート実行環境（Claude Code on the web）のため、人間のレビュー往復を待つ
ステップ（flow-id 2-3/2-4, 2-8/2-9, 3-3/3-4, 3-8/3-9, 4-3/4-4, 4-8/4-9）を省略し、調査・実装・
設計反映を1セッションへ圧縮して実施した。**そのため41ステップの進捗表は作成しておらず、
`plans/` `worklog/` `reports/` も作成していない（実施内容は下記「やったこと」を参照）。

## やったこと

- issue #38 の受け入れ条件に沿って、検索スクリプト・スキル・単体テスト・仕様・DDRを新規作成した。
- `.claude/scripts/src/search-frontmatter.sh` を新規作成。index.jsonlの最新化 → 全index.jsonlの
  結合 → 絞り込み（type/tag/keyword/path/text/since/until）→ 並び替え（path/mtime/type/title）→
  整形（table/path/json/jsonl/detail/count）を1コマンドで行う。
- `.claude/skills/doc-search/SKILL.md` を新規作成。grepとの使い分け表・使い方・jqレシピ6種
  （タグのAND、type別件数、frontmatter欠落の洗い出し、タグ語彙の集計、superseded DDR、md表化）を
  記載した。**jqレシピは6種すべて実リポジトリに対して実行し、出力を確認済み。**
- `AGENTS.md`・`.claude/rules/markdown-frontmatter.md`・`index.md`・
  `.claude/skills/apply-mr-workflow-to-project/SKILL.md` へ「ドキュメント探索は全文探索より先に
  インデックス検索を使う」方針と新資産を反映した。
- `.claude/scripts/test/test_search_frontmatter.sh`（66件）を追加。既存7本と合わせて全8本が
  `failures=0` で通ることを確認した。
- 実装中に見つけて直した不具合2件（詳細は spec「実装上の判断」節）:
  - jqの `any(gen; cond)` の中で `$h | contains(.)` と書くと `.` が `$h` へ差し替わり、
    **部分一致（`--path` / `--text`）が常に全件ヒット**していた。`. as $n` で束縛して修正。
  - `--until 2026-08-05` のような日付のみの指定で、辞書順比較のため**当日更新分が丸ごと落ちて
    いた**。日付のみなら `T23:59:59` を補う正規化を追加（単体テストで検出）。
- 表形式の桁揃えは、jqの `length` がコードポイント数を返すため日本語でずれる。全角を幅2として
  数える `dwidth` を定義して補正した。

- **敵対的レビュー（フェーズ4・1/3回目）を実施し、指摘を修正した。** 12件検出のうち確度high の
  8件をPR #104 へインラインコメントとして投稿し、確度medium のうちユーザー指示の2件と合わせて
  **10件すべてを修正**した。**12件すべて、投稿前に呼び出し元で実機再現を確認している。**
  - **`--text` がJSONのキー名にも当たっていた**（`match_sub` の haystack がレコードの
    `tostring`）。`--text description` で82/85件、`--text mtime` で全件がヒットしていた。
    検索対象を `concept_id` ＋ `mtime` ＋ frontmatter配下の**値**だけに変更。
  - **`--format detail` が `tags`/`keywords` スカラーのレコードで jq ごと落ちていた**（exit 5）。
    `arr_raw` でスカラーを配列へ包む形に統一。
  - **値を取るオプションの検証が無く、値の省略は無言でexit 1、後続フラグは無言で食われていた。**
    `sf_validate_option_value` を追加（`--` で始まる値だけを弾き、`--text -A` は通す）。
  - `--limit` が件数サマリを汚していたのを、打ち切り**前**の件数を `matched=` とする形へ修正
    （打ち切りが起きたときだけ `shown=` を付ける）。
  - `find -prune` のリストを `SF_EXCLUDED_DIRS` から組み立てるようにし、二重管理を解消した
    （`build` が prune 側に無かった）。
  - spec「影響範囲」のDDR番号 0045→0048 訂正、`.claude/docs/README.md` の**spec一覧**への追加漏れ、
    SKILL.mdの規約違反検出レシピがissueテンプレート（規約上の対象外）を誤検出する点を修正。
  - `--dir` がリポジトリルート基準であることを spec・SKILL.md・usage・エラーメッセージへ明記。
- **`main` の結合テストを追加した**（`mktemp -d` + `git init` の使い捨てリポジトリでスクリプトを
  実プロセス起動）。単体テストは66件→114件。**修正前のスクリプトに対して新テストが17件落ちることを
  確認済み**（テストに実効性があることの検証）。

## 次にやること

- （人間）変更内容のレビュー。
- （人間）PR #104 のレビュー。敵対的レビューの指摘は修正済みだが、**Draftのまま**である。
- （人間）Draft解除の指示（flow-id 5-4）。
- （人間）マージ。AIエージェントは明示指示があるまでマージしない。
- 敵対的レビューの残り実施可能回数はフェーズ4で 2/3（`adversarial-review-count.sh get 4`）。
- flow-id 5-1（`plans/` `worklog/` `reports/` の削除）へ戻る必要は無い（いずれも作成していない）。

## 判断を迷った内容

- **単体テストの置き場所**。issue #38の受け入れ条件は「`tests/` 配下」と書いているが、issue #63で
  「機構自身の単体テストは `.claude/scripts/test/` 配下へ置く」と決まっており（DDR 0031）、
  リポジトリに `tests/` は存在しない。**後続の決定であるDDR 0031を優先**し、
  `.claude/scripts/test/test_search_frontmatter.sh` として追加した。
- **`--tag` を複数指定したときの意味をORにするかANDにするか**。タグは「すべて持つもの」を
  探したい場面が多いが、`--type` はORが自然であり、オプションごとに規則が変わると覚えられない。
  「同じオプションの繰り返しはOR／異なるオプション同士はAND」の1文で説明しきれることを優先し、
  タグのANDはスキルのjqレシピへ回した（却下案としてDDR 0049に記載）。
- **`--` で始まる値を弾くか**。`--type --quiet` のような取り違えを検出するために弾いたが、
  裏返しとして `--` で始まる文字列そのものを `--text` の検索語にできなくなる。ハイフン1つで
  始まる値（`-A` 等、`keywords` に実在する）は通すため、実害は小さいと判断した。
- **既定の並び順を `path` にするか `mtime` の新しい順にするか**。同じ条件なら常に同じ順で返る
  （結果を再利用しやすい）ことを優先して `path` を既定にし、新しい順は `--sort mtime -r` とした。

### 前タスク（issue #86）から引き継いだ記録

- **DDR番号を2回繰り下げた**（`main` がレビュー中にさらに進んだため）。
  - 1回目: `main`（issue #50 / PR #96、issue #95 / PR #98）が 0041・0042 を使用済みだったため
    **0041 → 0043**。
  - 2回目: `main`（issue #92 / PR #100）が 0043 を使用済みだったため **0043 → 0044**。
  - いずれも「defaultブランチ側を正とし作業ブランチ側を繰り下げる」規則どおり。ファイル名・
    frontmatterの `title`・本文見出し・`.claude/docs/README.md` の一覧・`SKILL.md`／`Provider.sh`／
    spec からの参照をすべて更新した。
- `.claude/docs/spec/issue-mr-workflow.md` の「影響範囲」は、先にマージされた issue #50 →
  issue #92 → 本ブランチの issue #86、という時系列順で全エントリを残した（類型D）。
  **他issueのエントリ本文は書き換えていない。** `sed` による一括置換が他issueのエントリまで
  及びかけた（`（DDR一覧へ00NNを追加）` の行）ため、2回とも該当行を元の番号へ戻している。
- `.claude/docs/README.md` のDDR一覧は両ブランチの追記をどちらも残し、番号順に並べ直した（類型C）。
- `.claude/rules/docs-workflow.md` の `HANDOFF.md` 行は、本ブランチの変更（41ステップ・
  flow-id 5-4）と `main` 側 issue #93 の変更（ヘッダへ「現在のループ」を追加）が同一行で
  競合したため、**両方の意図を1行へ統合**した（類型C）。

## 未解決の内容

（無し）

## 守るべき条件・触ってはいけない範囲

（無し）
