---
title: worklog 20260820 issue43 実装・テスト（push3）
type: log
description: issue #43 のレビューコメント出力ソーススライス化における、実装フェーズの試行錯誤ログ
tags: [worklog, implementation, vcs]
keywords: [正規化JSON, スライス, バイト上限, jq, fork, 単体テスト, CR]
---

# worklog: 【実装】【テスト】レビューコメント出力のソーススライス化

対象: issue #43 レビューコメント取得の出力仕様見直し（2026-08-20）。
全体作業計画: `plans/issue43-review-comment-source-slice.md`
個別作業計画: `plans/【実装】【テスト】レビューコメント出力のソーススライス化.md`
push回数: 3

## 試したこと

- `local LC_ALL=C` でバイト単位の `${#s}` / `${s:0:n}` が得られるかを実機確認した
  （`あいう` が 9 と返り、先頭バイトが 227 と取れた）。forkせずにバイト長を測る手段として使える。
- jq の `@base64d` / `-R -n inputs` を単発で試し、中間表現の候補を比較した。
- スライス生成 → 整形の一連を、実リポジトリのファイル（`AGENTS.md`・
  `.claude/rules/docs-workflow.md`）と合成の正規化JSONで通した。

## うまくいったこと

- **`local LC_ALL=C` でバイト単位の切り詰めができた。** UTF-8の継続バイト（0x80-0xBF）を
  末尾から落とし、多バイト文字の先頭バイト（0xC0以上）で終わっていたらそれも落とす、という
  後始末で文字が壊れない（`あいうえおかきくけこ` を20バイト上限で切ると `>>> 1 | あいう`＝17B）。
  `printf -v ord '%d' "'${s: -1}"` はbash組み込みなのでforkしない。
- **中間表現に base64 を使わず済んだ。** `\037`（unit separator）で始まるヘッダ行＋本文行という
  レコード形式にし、jq側で `startswith("\u001f")` で分解した。これで
  `build_review_source_slices` 全体のjq起動が2回に収まり、ループ内は `git` のみになった。
- バイト上限の効きを実測できた。`.claude/rules/docs-workflow.md` の line=30 で
  **8,971B → 1,979B**、全体のばらつきも 13.1倍 → 2.3倍。
- フォールバック4段階のうち、段階1（ローカルblob）・段階3（現HEAD）・段階4（ソース無し）を
  実際に発火させて出力を確認した。

## ダメだったこと

- **`content="$(read_source_at_ref ...)"` と書いて `REVIEW_SOURCE_REF: unbound variable` で落ちた。**
  コマンド置換がサブシェルをforkするため、関数内で設定したグローバルが呼び出し元へ伝わらない。
  `read_source_at_ref_to_reply` へ改名し `REPLY` へ返す形にした。
  `.claude/rules/shell-script-style.md` の「`REPLY` へ返す」は**性能**を動機に書かれており、
  「**戻り値が複数あるとき**にも同じ形が要る」ことは書かれていない（AIアセット反映の候補）。
- **ソースファイルへ生の制御文字（0x1F）を書いてしまった。** `startswith("<0x1F>")` はjqとしては
  正しく動くが、ツール経由でコマンドを組み立てる際に弾かれ、diffでも見えない。
  jqのエスケープ `"\u001f"` へ置き換えた（bash側は `printf '\037...'` で元からエスケープ表記）。
- **`(場所不明)` の扱いで単体テストが4件落ちた。** GitHubの旧実装は `path` が null のとき
  `(場所不明)` と出していたが、共通化するとGitLabのMR全体へのコメント（`position` を持たないのが
  **正常**）にも付いてしまう。位置が無いときは何も出さないことにした。

## 次の一歩

- flow-id 3-7（commit・push）→ 4-1（個別反映計画。spec / DDR 0059 / SKILL.md）へ進む。
