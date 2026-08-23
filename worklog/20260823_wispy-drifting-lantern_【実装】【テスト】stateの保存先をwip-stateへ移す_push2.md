---
title: worklog 20260823 stateの保存先をwip/stateへ移す push2
type: log
description: .claude/state を wip/state へ移す作業の詳細ログ（push2）
tags: [worklog, workflow, distribution]
keywords: [wip, state, gitignore, dist-layers, check-dist-coverage, sync-gemini-assets, テスト, issue184]
---

# worklog: 【実装】【テスト】stateの保存先を `wip/state` へ移す

対象: ローカル作業状態の保存先を `.claude/state/` から `wip/state/` へ移す（2026-08-23）。
全体作業計画: `plans/wispy-drifting-lantern.md`
個別作業計画: `plans/【実装】【テスト】stateの保存先をwip-stateへ移す.md`
push回数: 2

## 試したこと

- **issue #184 の本文取得。** `mcp__github__issue_read` の `get` は `body` を返さず、
  `search_issues` / `list_issues` に `fields: ["body"]` を付けても `body` が `null` だった。
  同じ手順で issue #165 の本文は取得できたため、MCPの制限ではなく**issue #184 の本文が
  実際に空**だと判断した（タイトルと、マージ前通知のコメント1件しか無い）。
- **出現箇所の列挙。** `grep -rn '\.claude/state' --include='*.md' --include='*.sh'
  --include='*.json' --include='.gitignore' .` を `.gemini/` を除いて実行し、14ファイルを得た。
- **`check-dist-coverage.sh` が何を検査するかの確認。** `usage()` と実装を読み、この変更が
  触るのは検査2（`.gitignore` の全行が `local` エントリの `gitignorePattern` に被覆されて
  いるか）だけであることを確かめた。`.claude/state` は追跡ファイルを持たないため
  `path` エントリが元々存在せず、検査1・検査3には現れない。

## うまくいったこと

- **`.gitignore` のパターンを `/wip/state/` に留めた。** `/wip/` にすると #165 が置く予定の
  `wip/plans` `wip/worklogs` `wip/reports`（追跡対象）が丸ごと無視される。禁止事項として
  `.gitignore` のコメントにも残した。
- **`dist-layers.json` の `note` を実態へ合わせた。** 元の「前回push時点のHEAD SHA」は
  `post-push-compact-prompt.sh` の分しか指しておらず、`adversarial-review-count.sh` が同じ
  ディレクトリへ書く投稿件数が漏れていた。
- **検証がすべて通った。** 単体テスト3本（22 / 91 / 99 件、いずれも `failures=0`）、
  `check-dist-coverage.sh`（4種すべて通過）、`git check-ignore -v wip/state/.probe`
  （`.gitignore:26:/wip/state/` にマッチ）。

## ダメだったこと

- **`test_sync_gemini_assets.sh` のフィクスチャを、当初 `wip/state/` へ置き換えようとしたが
  誤りだった。** このT8は「`.gitignore` 対象のファイルが `.gemini/` へ出ないこと」を確かめる
  テストだが、`sync-gemini-assets.sh` の列挙は `git ls-files … -- .claude` に限られる。
  `wip/state/` を使うと**`.gitignore` の効果と無関係に列挙対象外**になり、テストが
  **常に成功する空振り**へ変わる。`.claude/` 配下に残る `.gitignore` 対象の実在パス
  （`/.claude/settings.local.json`）へ差し替えることで、検証したい性質を保った。
  - 教訓: **パスの一括置換でテストを追従させるとき、置換後のパスがそのテストの
    「検証したい経路」に乗っているかを確かめる。** 乗っていないと、テストは緑のまま
    何も検証しなくなる（`.claude/rules/shell-script-style.md`「異常が無ければ何も出ない検証」と
    同根の罠）。
- **`.gitignore` のパターンを差し替えただけでは足りなかった。** 差し替えた直後に
  `git status` へ `?? .claude/state/` が現れた（push1でhookが旧パスへ書いた状態ファイルが
  ignore対象から外れたため）。同じことは既存の全開発者・全配布先で起きる。旧パスの除外行を
  「移行用の名残」として残し、`dist-layers.json` にも対応する `local` エントリを足した。
  - 教訓: **ローカル状態のパスを変えるときは、新パスを ignore するだけでなく、
    旧パスの ignore を残すかどうかを必ず判断する。**
- **issueのコメントが述べていた「`dist-layers.json` の2箇所」は実際には1箇所だった。**
  `path` エントリは存在しない（`.claude/state` は追跡ファイルを1件も持たないため、
  追跡ファイルを分母とする検査1・検査3に現れず、`path` を置く必要が無い）。

## 次の一歩

- フェーズ4〈反映〉: rules・spec 4本の更新、DDR `i0184-01` の新規作成、DDR一覧の再生成。
- flow-id 5-3: `.gemini/` の変換同期。

---
