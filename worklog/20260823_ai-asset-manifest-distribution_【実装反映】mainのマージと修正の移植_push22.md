---
title: worklog 20260823 mainのマージと【実装反映】の修正の移植 push22
type: log
description: main（PR #157）を取り込み、.gemini/を変換生成物として扱う設計へ統合し、失敗握りつぶしの修正をsync-gemini-assets.shへ移植した際の試行錯誤ログ
tags: [worklog, マージ, gemini, 失敗握りつぶし]
keywords: [main取り込み, sync-gemini-assets, run_or_fail, プロセス置換, 削除ガード, dist-layers, exclude, フェーズ5番号繰り下げ, install-to-project手順7]
---

# worklog: `main` のマージと `【実装反映】` の修正の移植

対象: issue #26（2026-08-23）。push回数: 22。
全体作業計画: `plans/ai-asset-manifest-distribution.md`

## 試したこと

- **マージは `--no-ff --no-commit` で開始し、9件のコンフリクトを類型別に解消した**
  （`resolve-conflict` スキルの Step 3〜4）。ファイル単位で片側を丸ごと採ったのは
  `.claude/docs/README.md` のDDR一覧（類型B。マーカー外に差分が無いことを先に確認し、
  `generate-ddr-list.sh` で再生成）だけである。
- **`【実装反映】` の修正の移植先を、憶測でなく再現で決めた。** `setup-gemini-links.sh` は
  main で削除済みなので、後継の `sync-gemini-assets.sh` を「同じ類型（失敗が成功として
  報告される）が無いか」という観点で読み直した。
- **見つけた穴は、直す前に必ず再現した。** 使い捨てリポジトリを作り、`PATH` の先頭へ
  「呼ばれたら必ず失敗する」スタブ（`find` / `git`）を置いて実行した。
- **回帰テスト（T18・6件）が修正前の実装で落ちることを確認した。** 作業ツリーを丸ごとコピーし、
  実装ファイルだけを `git show :<path>`（ステージ済み＝修正前）へ差し替えて流した。

## うまくいったこと

- **削除ガードが無言で失効する経路を実測できた。** `find` が失敗すると
  `while … done < <(list_gemini_removed_files …)` が「0件」に見え、その直後の
  `rm -rf .gemini` が走る。配布先が自前で置いた `.gemini/commands/mine.toml` が
  **終了コード0のまま消えた**。元の `setup-gemini-links.sh` の不具合より重い
  （あちらは「作られなかった」だが、こちらは「消した」）。
- **既存のテストが、マージが持ち込んだ食い違いを2件とも捕まえた。**
  - `test_cleanup_task.sh`: main が `HANDOFF_TEMPLATE` へ `- 未返信スレッド: 0` を足したが、
    issue #26 が置いた配布用の写し（`assets/HANDOFF.md.template`）が追随していなかった。
    **写しの一致を機械的に表明しておいたことが、そのまま効いた。**
  - `test_install_to_project.sh` B-7: 手順7が `sync-gemini-assets.sh` を**本家のカレント
    ディレクトリのまま**呼んでいた。同スクリプトは `cd "$(git rev-parse --show-toplevel)"` で
    対象を決めるため、**本家の `.gemini/` を作り直し、配布先には何も作らない**。
- **`.gemini/` の層は `local` + `core` の2エントリから `exclude` の1エントリへ畳めた。**
  「配らずに配布先で生成する」という main の意図が、そのまま層の語彙で表せた。

## ダメだったこと

- **B-7 を直したら別の2件が落ちた。** `.gemini/` が `.claude/` の変換コピーである以上、
  `find "$dest" -name 'REVIEW-POINTS.md'` は4件ではなく5件を数える。テストの期待値ではなく
  **数え方**（`.gemini/` を `-prune` する）を直した。**設計が変わったのだから期待値を
  合わせにいく、という判断を1回で通さず、なぜ増えたのかを先に確かめた。**
- **`.gemini/` が `.claude/` と食い違ったままマージを終えかけた。** マージが
  `.claude/skills/…/sync-assets.sh` を削除したのに、`.gemini/` 側の生成物が残っていた。
  flow-id 5-3 の担当だが、**食い違いを作ったのはこのマージなので**、この場で
  `--force` を付けて再生成した（消えるのは元が消えた生成物1件だけであることを確認済み）。
- **spec の表のセルに `||` を書いてしまい、表が壊れた。** markdown の表でパイプは列区切りに
  なる。生成直後にセル数を数えて気づいた（`awk -F'|' '{print NF-2}'`）。

## 次の一歩

- flow-id 4-7（commit・push してレビュー依頼）。マージの解消内容は PR #154 へコメントする
  （`resolve-conflict` の監視モードは、報告先にPRのコメントを含めることを求めている）。
- その後 4-8/4-9 → 4-10（`describe`）→ **フェーズ5（7ステップへ増えた）**。
