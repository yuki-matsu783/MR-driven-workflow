---
title: worklog 20260819 【調査】インラインコメント投稿APIとセッション種別判定 push3
type: log
description: issue #77 フェーズ2の作業ログ（push3）。調査結果を個別調査計画から reports/ 配下のmarkdownへ分離し、ルールをissue化するまでを記録する。
tags: [worklog, issue-mr-flow, research, docs]
keywords: [worklog, issue77, 調査結果, reports, 個別計画, 分離, issue87, レビュー指摘]
---

# worklog: 【調査】インラインコメント投稿APIとセッション種別判定

対象: issue #77 MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する（2026-08-19）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別作業計画: `plans/【調査】インラインコメント投稿APIとセッション種別判定.md`
push回数: 3

## 試したこと

- flow-id 2-9（レビュー指摘への対応）。指摘はMRのスレッドではなくチャットで受け取った
  （`get_mr_unresolved_comments 80` では未解決スレッド0件。存在するのは対応工数レポートの
  自動コメントのみ）。そのため `reply` は行っていない。
- 指摘内容: **調査結果を個別調査計画へ書かないこと。結果は `reports/` 配下のmarkdownへ格納する。**
- 対応として次を行った。
  - `plans/【調査】〜.md` の `## 調査結果` 節（104〜207行）を
    `reports/20260819_prancy-herding-kahan_インラインコメント投稿APIとセッション種別判定.md` へ移した。
    見出しレベルは `###` → `##` へ繰り上げ、frontmatter（`type: report`）と
    「調査計画・worklog・HTMLレポートへの参照」を先頭に付けた。
  - 計画側は `## 進め方・成果物` の項目2を「**調査結果は本ファイルへ書かない**」へ書き換え、
    結果節を削除した（計画ファイルは計画のみを表す状態へ戻した）。
  - HTMLレポート末尾の参照先を、計画の「調査結果」節から新しいmdへ差し替えた。
  - `HANDOFF.md` の flow-id 2-6 の行と「やったこと」の記載を、結果の置き場所に合わせて更新した。
- ルールの明文化を `issue-create` スキルでissue化した（**issue #87**）。

## うまくいったこと

- 節の切り出しは `sed -n '104,207p' ... | sed 's/^### /## /'` の1パスで済み、内容の改変は無い。
- 計画側の差し替えは `{ sed -n '1,85p'; cat part.md; sed -n '90,95p'; }` の連結で行い、
  `.claude/rules/shell-script-style.md` の指示どおり差し込み位置の前後を目視確認した
  （空行の二重・見出しの貼り付きは無し）。
- 重複チェックで **#54「計画・レポートの記述の型をテンプレートファイルへ切り出す」** が見つかった。
  土俵は重なるが、#54 は「記述の型（何を書くか）」、#87 は「置き場所（計画と結果を分ける）」で
  決めている軸が違うと整理し、ユーザー判断で新規起票とした。#87 の本文に棲み分けを明記している。

## ダメだったこと

- 実行環境のpythonが Python 2 で、`io.open(..., encoding=)` を使ったワンライナーが
  `SyntaxError: Non-ASCII character` で失敗した（coding宣言が無いため）。
  日本語を含む置換は素直に `sed` で行うほうが速い。区切り文字は `/` を避けて `|` を使う。
- `reports/*.md` は `.claude/rules/markdown-frontmatter.md` の「typeの値」表に無いため、
  暫定で `type: report` を使った。表への追記は #87 の受け入れ条件に含めてある。

## 次の一歩

- flow-id 2-7 相当（commit・リモートへ反映・レビュー依頼）を行い、再度 flow-id 2-8 のレビューを受ける。
- 合意後、flow-id 2-10（`describe`）→ フェーズ3（3-1: 個別作業計画の作成）へ進む。
