---
title: worklog issue-createスキルの最終確認と着手導線の見直し
type: log
description: issue #59でissue-createスキルの最終確認をAskUserQuestion化し、起票後の同一セッション着手導線を撤去した際の作業ログ
tags: [worklog, issue-create, skill, askuserquestion]
keywords: [issue-create, AskUserQuestion, issue-mr-flow, HANDOFF, 新セッション, 最終確認, 着手導線, spec反映, DDR判断]
---

# worklog: 【実装】【設計反映】issue-createスキルの最終確認と着手導線の見直し

対象: issue #59（2026-08-19）。
全体作業計画: 未作成（非対話的実行環境のためPlanモードでの作成・合意を省略）
個別作業計画: `plans/【実装】【設計反映】issue-createの最終確認と着手導線の見直し.md`
push回数: 1

## 試したこと

- issue #59 の本文を `mcp__github__issue_read` で取得（この実行環境には `gh` CLI が無く、
  `get_vcs_access_mode` は `mcp` を返す想定。AGENTS.md・SKILL.mdの「MCPフォールバック」節に従った）。
- 変更前の `.claude/skills/issue-create/SKILL.md` を読み、手順2が「ユーザーに提示し確認を取る」
  としか書かれておらず確認手段が指定されていないこと、手順4が同一セッションでの着手導線に
  なっていることを確認した。
- 記述スタイルの参照元として `.claude/skills/issue-mr-flow/SKILL.md` のベースブランチ確認節
  （行190付近）を確認。「選択肢は次の方針で組み立てる」＋箇条書き、`(Recommended)` を選択肢
  ラベルの末尾へ付ける、選択式に収まらない入力は「続けて通常のプロンプトで尋ねる」と書く、
  という3点の書き方をそのまま踏襲した。
- spec反映の要否判断のため `.claude/docs/spec/issue-mr-workflow.md` を検索し、
  「issue作成（AIエージェント代行・スクリプト実行）（issue #25）」節（行845〜）が本スキルの
  現在の正史を持っていることを確認した。

## うまくいったこと

- 手順2を2段構え（本文は通常メッセージで全文提示 → `AskUserQuestion` は可否選択のみ）に分けて
  書いたことで、「issue本文が長く選択肢に収まらない」という制約と「公開操作の直前は選択式で
  意思表示を取り違えない」という要求を両立できた。
- 手順4は「勧めるに留める」「AIから持ちかけない」を分けて書いた。前者だけだと、案内した直後に
  AIが「では着手しますか？」と続けてしまう余地が残るため。
- `HANDOFF.md` を更新しない理由を「まだブランチが無い／更新はflow-id 1-6の担当」と責務の所在まで
  書いた。禁止だけを書くと、後から「親切のつもりで」再び書き込まれかねないため。
- 「してはいけないこと」は受け入れ条件の1項目に加えて `HANDOFF.md` 非更新も入れ、手順4の本文と
  重複させた。この節だけを読んで判断するケースがあるため、あえて冗長にしている。
- spec反映は、`issue-create` スキルを説明する既存の箇条書きへ**入れ子の下位項目として追記**する
  形にした。過去issueのchangelog（「## 影響範囲」の各エントリ）は書き換えず、issue #59用の
  エントリを新規追加している（`.claude/rules/docs-workflow.md` の規定どおり）。
- `.claude/scripts/test/` の6本を実行し `passed=157 failures=0`（13/17/35/15/33/44）を確認。
  今回は文書のみの変更のため回帰は想定していないが、変更前後で差が無いことの確認として実施した。

## ダメだったこと

- 特になし。

## 判断したこと

- **DDRは新設しない。** `AskUserQuestion` による承認確認（issue #15のベースブランチ確認）も、
  起票と実装のスキル分離（DDR 0011）も既に決定済みの方針であり、今回はそれを `issue-create` の
  最終確認・事後案内へ適用しただけで、却下案を伴う新しい意思決定を含まないため。
- **`create-issue.sh` / `Provider.sh` は変更しない。** 確認手段と起票後の案内はスキル側の責務で、
  スクリプトの入出力仕様は変わらないため。

## push2: mainとのコンフリクト解消（flow-id 5-2）

- `check-base-conflicts.sh` が `hasTextualConflict: true`（`.claude/skills/issue-create/SKILL.md`,
  `HANDOFF.md`）を検知。`hasDuplicateDdrNumber` は `false`。
- `origin/main` を `--no-ff --no-commit` でマージ（`resolve-conflict` スキルの絶対ルールどおり
  rebase・force反映は使わない）。
- **`issue-create/SKILL.md`（類型C）**: main側の issue #68 が手順2「類似・重複issueをチェックする」
  を新設し、各手順へ見出し名を併記する形へ再構成していたため、本ブランチが変更した旧手順2・
  旧手順4と競合した。**main側の構成・番号・見出しスタイルを正とし、issue #59 の変更内容を
  新しい手順3〈ユーザーへ最終確認する〉・手順5〈結果を提示する〉へ載せ替えた。**
  「してはいけないこと」は両側の4項目をすべて残し（issue #68分が先、issue #59分が後ろ）、
  frontmatterの `keywords` も両側を統合した。
- **`HANDOFF.md`**: main側は PR #76（issue #61）時点の内容。このファイルは「常にこのブランチの
  現状」を表すため統合の意味が無く、本ブランチの内容を採用。ただしmain側（issue #46・#61）で
  フェーズ5のflow-idが 5-2〈コンフリクト検知〉挿入・5-3〈Draft解除〉・5-4〈マージ〉へ
  変わっていたため、進捗表をその番号へ追随させた。
- **spec のissue #59エントリ**: 「手順2」「手順4」と書いていた箇所が、main側の再構成後は
  手順3・手順5に当たるため番号を修正した。個別には正しい記述が組み合わせでずれる型で、
  マージ時に見落としやすい。
- 検証: マーカー残存なし・`git diff --check` クリーン・DDR番号重複なし・テスト6本すべて
  `failures=0`（13/17/35/15/33/54＝167件。main側のissue #61/#68分でtest_vcs_providerが44→54件）。

## 次の一歩

- 特になし（実装・設計反映とも完了）。人間レビューを挟めない非対話セッションのため、
  フロー進捗表のループ範囲（3-3〜3-4, 3-6〜3-9, 4-3〜4-4, 4-6〜4-9）は `[]` のまま残している。
