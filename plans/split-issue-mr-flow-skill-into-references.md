---
title: 全体作業計画 — issue-mr-flow/SKILL.md の references/ 分割（issue #160）
type: plan
description: SKILL.md本文を入口へ絞り、詳細をreferences/へ切り出し、読むタイミングを全体フロー表とSessionStart hookで機械的に決めるための全体作業計画
tags: [issue-mr-flow, skill, plan, workflow]
keywords: [SKILL.md, references, 段階的詳細化, SessionStart hook, flow-id, 参照追従, 旧節名対応表, 配布, 分割, 死荷重]
---

# 全体作業計画 — issue-mr-flow/SKILL.md の references/ 分割（issue #160）

- issue: #160
- ブランチ: `claude/skill-split-references-z17fw4`
- PR: #161（Draft）

## この計画で何をするか

`.claude/skills/issue-mr-flow/SKILL.md`（1446行 / 132KB）を、**入口に絞った本文**と
`.claude/skills/issue-mr-flow/references/` 配下の**詳細ファイル群**へ分割する。ただし
**「いつ読むか」を機械的に決める仕組みとセットで行う**。参照ファイルを開くかどうかをAIの判断へ
委ねる形（本文にポインタを置くだけ）は、手順が黙って抜ける失敗モードを新設するだけで、
issue #113・DDR i0057-01 が退けたのと同型の劣化になる。

「機械的に決める」の実体は次の2つである。

1. **全体フロー表の各行に、そのステップの実行前に開く参照ファイルを明記する**（表を読めば
   開くべきファイルが決まる。AIが「必要そうか」を判断する余地を残さない）。
2. **SessionStart hook が `HANDOFF.md` の現在地から参照ファイルを名指しで注入する**
   （セッション開始・compact直後という、本文を読み直す唯一の機会に効かせる）。

## 変更対象

| 領域 | 何をするか |
|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 入口へ絞る（500行の目安）。全体フロー表へ参照ファイル列を足し、旧節名→新パスの対応表を置く |
| `.claude/skills/issue-mr-flow/references/*.md`（新規） | 切り出した詳細。分割単位は「いつ読むか」 |
| `.claude/hooks/session-start.sh` | 現在地flow-id → 参照ファイルの解決と注入を足す |
| `.claude/scripts/test/test_session_start.sh` | 上記の純粋関数の単体テストを足す |
| `.claude/scripts/test/test_install_to_project.sh` | `describe` 見出しの抽出元を追従させる |
| `.claude/rules/markdown-frontmatter.md` | typeの値の表へ `references/*.md` の扱いを追記する |
| 参照元40ファイル前後（`AGENTS.md`・`.claude/rules/`・`.claude/docs/spec/`・他スキル） | リンク切れの解消。**DDR本文・specの過去changelogは書き換えない** |
| `.claude/docs/spec/issue-mr-workflow.md`・`.claude/docs/ddr/` | フェーズ4で反映 |

## 方針

- **切る軸はサイズではなく「いつ読むか」**。同じタイミングで必要になるものを1ファイルにまとめ、
  別のタイミングでしか要らないものを混ぜない。
- **省略が不可逆・無言になる内容は本文に残す**（不変条件: `commit` スキル経由の強制／マージは
  人間／`HANDOFF.md` の進捗更新／レビュー往復）。参照ファイルを開き損ねても、これらだけは
  本文にあるので守られる。
- **参照追従は機械的な一括置換で行わない。** `.claude/rules/docs-workflow.md` が、DDR本文と
  specの過去changelogへの一括置換を禁じている（過去に歴史を壊しかけた実例がある）。
  **旧節名→新パスの対応表を SKILL.md 側へ置く**ことで、書き換えずに辿れる状態を作り、
  そのうえで「現在の状態を説明している参照」だけを個別に判断して更新する。
- **hookの拡張は fail-open**。解決に失敗しても、従来の注入（ブランチ・issue・PR・HANDOFF抜粋・
  SKILL.md再読み込み指示）を壊さない。

## フェーズ2〈調査〉

**実施する。** 分割の設計は、実データを見ないと決められない項目が多い。

| 調査項目 | なぜ要るか |
|---|---|
| A. H2/H3ごとの行範囲・バイト数・相互参照（節→節のリンク）の実測 | 「いつ読むか」で切ったときに、節をまたぐ相互参照がどれだけ生じるかを知らないと分割単位を決められない |
| B. 参照元の全量分類（節名を伴う参照 / パスのみの参照 / DDR本文 / specの過去changelog / 現在の状態を説明する節） | 書き換えてよい参照とそうでない参照の線引きは、件数ではなく1件ずつの性質で決まる |
| C. SessionStart hook で「現在地flow-id」を得る手段の確認（`HANDOFF.md` の進捗表・ヘッダから何が読めるか、`update-handoff-progress.sh` の記号規約） | 受け入れ条件が hook 拡張を求めている。読めない場合は理由を記録して代替へ倒す必要がある |
| D. `test_install_to_project.sh` の `describe` 抽出と、`sync-assets.sh` の配布経路の実測 | 壊れるテストの追従と、`references/` が配布先へ渡ることの確認 |
| E. 分割単位の案（複数）と、それぞれの死荷重削減量の見積り | 「サイズだけで機械的に割る」案を却下する根拠をDDRへ残すため |

結果は `reports/日付_split-issue-mr-flow-skill-into-references_調査.md`（＋ `.html`）へ書く。

## フェーズ4〈反映〉

**反映対象は flow-id 4-1 で洗い出す。** 現時点で見込んでいるのは次のとおり（確定した反映内容
ではなく候補である）。

- `.claude/docs/spec/issue-mr-workflow.md`: SKILL.md の構成（本文＋references/）と、
  SessionStart hook の注入項目の追加
- `.claude/docs/ddr/i0160-01-…`: 分割の判断と却下案（分割しない／サイズだけで機械的に割る／
  読むタイミングをAIの判断に委ねる）
- `.claude/rules/markdown-frontmatter.md`: typeの値の表へ `references/*.md` の扱い
- `.claude/rules/directory-structure.md`: `references/` の実例（現時点で「実例なし」と書かれている）

## やらないこと（スコープ外）

- **他の8スキルの点検・スキル執筆規約の新設**（issue #129 の担当。本issueは #129 から分割部分を
  切り出したもの）。
- **フロー自体の変更**（flow-idの増減・ステップの並べ替え・手順の中身の変更）。本issueは
  **同じ内容をどこに置くか**だけを変える。文言の改善が必要だと気づいた場合も、本issueでは
  移動に留め、変更は別issueへ切り出す。
- **DDR本文・specの過去changelogの書き換え**（`.claude/rules/docs-workflow.md` が禁じている）。
- **`.gemini/` 側の追従**（`.claude/` 配下へのローカルリンクであり、実体を編集すれば足りる）。

## 検証

- `.claude/skills/issue-mr-flow/SKILL.md` が500行以下。
- `references/*.md` の各ファイルが、全体フロー表またはサブコマンド一覧のいずれかから名指しで
  参照されている（孤児が無い）。
- 本文と `references/` の相互リンクにリンク切れが無い（実在しないパスを指す参照が0件）。
- `bash .claude/scripts/test/test_install_to_project.sh` が `failures=0`。
- `bash .claude/scripts/test/test_session_start.sh` が `failures=0`（hook拡張の単体テストを含む）。
- `bash -n .claude/hooks/session-start.sh`。
- `sync-assets.sh` → `install-to-project.sh` の経路で `references/` が配布先へ渡ることを実測。
- 旧節名→新パスの対応表が、**分割前の SKILL.md に存在したH2/H3をすべて網羅**している。

## issueの受け入れ条件との対応

| 受け入れ条件 | 対応するフェーズ |
|---|---|
| SKILL.md 本文が500行の目安に収まり、切り出した節が `references/` に置かれている | フェーズ3 |
| 全体フロー表の各行に参照ファイルが明記されている | フェーズ3 |
| 不変条件が SKILL.md 本文に残っている | フェーズ3 |
| SessionStart hook が現在地flow-idに対応する参照ファイルを名指しで注入する | フェーズ2（C）→ フェーズ3 |
| 旧節名→新パスの対応表がある | フェーズ3 |
| AGENTS.md・`.claude/rules/`・spec からの参照にリンク切れが無い | フェーズ2（B）→ フェーズ3 |
| `test_install_to_project.sh` が新構成で通る | フェーズ2（D）→ フェーズ3 |
| `.claude/rules/markdown-frontmatter.md` のtype表に追記 | フェーズ4 |
| `references/` が配布先へ渡ることを確認 | フェーズ2（D）→ フェーズ3 |
| DDRとして分割の判断と却下案を記録 | フェーズ4 |

## 比較検討した案

| 案 | 採否 | 理由 |
|---|---|---|
| 分割しない（現状維持） | 却下 | 毎セッション・compactのたびに128KBを読み直す指示が出ており、コストが繰り返し発生する。フェーズ3の実装中にフェーズ5専用の節が丸ごと死荷重になる |
| サイズだけで機械的に割る（例: 30KBずつ） | 却下 | 同じタイミングで必要な内容が別ファイルへ散り、開くファイル数が増えるだけで死荷重が減らない |
| 読むタイミングをAIの判断に委ねる（本文にポインタだけ置く） | 却下 | 手順が黙って抜ける失敗モードを新設する。issue #113・DDR i0057-01 が退けたのと同型 |
| **本文を入口に絞り、読むタイミングを全体フロー表とSessionStart hookで機械的に決める** | **採用** | 死荷重を減らしつつ、「唯一のフロー定義」という最大の価値を保てる |

## 進め方（レビューの扱い）

本セッションは人間のレビュー往復を待てない非対話的な進行である。ユーザーの指示により、
**各フェーズの計画で1回、各フェーズの作業結果で1回、`adversarial-review` スキルによる
敵対的レビューを自動で実施する**。人間担当のレビューステップ（2-3/2-4・3-3/3-4・4-3/4-4・
2-8/2-9・3-8/3-9・4-8/4-9）はこれで代替し、`HANDOFF.md` のループ範囲の進捗記号は `[]` のまま
残して、実施内容を「やったこと」へ文章で補足する
（`.claude/rules/docs-workflow.md` 末尾の非対話的実行環境の規定に従う）。
