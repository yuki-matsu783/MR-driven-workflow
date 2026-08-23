---
title: 作業結果 — SKILL.mdのreferences分割と参照タイミングの機械化
type: report
description: フェーズ3〈作業〉の実施結果。SKILL.mdを本文とreferences/7ファイルへ分割し、全体フロー表の参照列とSessionStart hookで読むタイミングを機械化した。検証14項目の結果と計画からの逸脱を記録する
tags: [issue-mr-flow, report, skill, session-start]
keywords: [references分割, 参照列, flow-id解決, ROW_RE, describe抽出, 参照追従, 例外リスト, 検証結果, skill-reference]
---

# 作業結果 — SKILL.mdのreferences分割と参照タイミングの機械化（issue #160 フェーズ3）

- 個別作業計画: `plans/【AIアセット作成】【実装】【テスト】SKILL.mdのreferences分割.md`
- 実施日: 2026-08-23。基準の分岐点: `git merge-base origin/main HEAD` = `0aa9874`

## サマリ（結論の一覧）

| # | 結論 | 根拠 |
|---|---|---|
| 1 | SKILL.md は本文 **177行 / 27,349バイト** と `references/` **7ファイル**になった（受け入れ条件#1の「500行以内」を満たす） | 検証 #1 |
| 2 | 本文は切り貼り以外で触っていない。元の見出し62件は全て残り（`comm -23` 0件）、増分は追加したH1 7件＋導入H2 1件＋対応表H2 1件のみ（`comm -13` 9件） | 検証 #2-(i) |
| 3 | 全行差分は「参照付け替え16行＋フロー表44行（参照列追加）」の旧側60行と、追加分の新側154行だけで、**説明の付かない差分は無い** | 検証 #2-(ii)・下記「例外リスト」 |
| 4 | 全体フロー表の**42行すべて**に参照列が入った（空セル0件） | 検証 #4 |
| 5 | SessionStart hook は現在地 flow-id（実データで `3-3`）と参照列を解決し、参照が `—`・解決不能のときは1行も出さない（fail-open） | 検証 #5・実機確認 |
| 6 | 既存テストは**16本 / passed=1018 / failures=0**。`require_vcs_cli` の出力を検証するテストを新設し、案内先を旧パスへ戻した一時ツリーで**実際に failures=1 になる**ことを確認した | 検証 #6・#7 |
| 7 | DDR本文の差分は**0行**。specの変更行のうち`## 影響範囲`配下は1件だけで、それは調査B-3が特定済みの「影響範囲の中の現在状態の小節（`### 呼び出し側の責務`）」への正しい追従である | 検証 #9 |
| 8 | `references/` は配布先へ**7ファイルすべて**渡る（`sync-assets.sh` 再ビルド後に実測） | 検証 #10 |
| 9 | `index.jsonl` に `type: skill-reference` で7件載り、`--type skill` の件数（8件）は変わらない | 検証 #11 |

## 実施した内容

計画の作業1〜7を、worklog記載の順（1→2・3→7→4→6→5）で実施した。

| 作業 | 実施内容 |
|---|---|
| 1 | 行の切り貼りスクリプト（worklogに全文）で本文＋7ファイルへ分割。`assert` で漏れ・重複なし。各 `references/*.md` へ frontmatter＋H1 を追加。`review-loop.md` へ導入H2「サブコマンド（レビュー往復系）」と共通前提の再掲を追加 |
| 2 | 全体フロー表へ「参照」列を追加（42行。参照不要な行は `—`） |
| 3 | 本文末尾へ「旧節名→新しい場所の対応表」（24行）を追加 |
| 4 | `session-start.sh` へ `ROW_RE`（`update-handoff-progress.sh` と同一リテラルの複製）・`current_flow_id_to_reply`・`refs_for_flow_id_to_reply` を追加。`format_skill_reload_instruction` は第2引数 `"${2:-}"`（既定値付き）で参照行を受け、ヒアドキュメントの外で出し分ける |
| 5 | 節名を伴う参照の追従: spec本体（`issue-mr-workflow.md`）の仕様節17件、その他の rules/skills/agents/spec/テンプレート 36件、分割で同一ファイルに閉じなくなった相対参照・アンカー10件 |
| 6 | `Provider.sh` 357/373行目・`session-start.sh` 187行目の実行時メッセージを `references/mcp-fallback.md` へ変更。`test_vcs_provider.sh` の期待値更新＋`require_vcs_cli` テスト3件新設。`test_install_to_project.sh` の `describe` 抽出は読むファイルを `references/review-loop.md` へ変え、**終端の規則 `/^## / { in_section = 0 }` を追加**。`test_session_start.sh` へ現在地解決5件・参照抽出4件・ROW_RE一致2件・参照行の出し分け4件を新設 |
| 7 | `markdown-frontmatter.md` の type 表へ `skill-reference` 行を追加 |

## 検証結果（計画の検証 #1〜#14）

| # | 合格条件 | 結果 |
|---|---|---|
| 1 | 500行以内・概ね25,000バイト以下 | **行数は合格**（177行）。**バイトは27,349で目安を9%超過**（対応表24行が想定より大きい。行数の受け入れ条件は満たすため許容し、ここに記録する） |
| 2-(i) | `comm -23` 0件・`comm -13` 9件 | **合格**（0件 / 9件。9件の中身はH1 7＋導入H2＋対応表H2） |
| 2-(ii) | 全行差分が例外リストと一致 | **合格**（旧側60行=表44＋付け替え16。新側154行=表67＋frontmatter/H1/導入H2/対応表/付け替え新側。下記「例外リスト」） |
| 3 | 被参照節名と対応表の差0件 | **合格**。DDR・spec過去changelogの「…」抽出19件のうち、節名12件は対応表がカバー。非節名7件（手順名・引用句・hookの見出し）は対象外と判断（内訳は下記） |
| 4 | 参照列の空データ行0件 | **合格**（42行 / 空0） |
| 5 | hookの新規テスト＋実データ確認 | **合格**（`test_session_start.sh` passed=66。実際の `HANDOFF.md` で現在地 `3-3`、`3-6`→`deliverables.md`・`9-9`→空を確認） |
| 6 | 全テスト failures=0（件数付き） | **合格**（16本 / passed=1018 / failures=0） |
| 7 | 変え忘れの検出 | **合格**（`Provider.sh:373` 相当を旧パスへ戻した一時ツリーで `passed=221 failures=1`） |
| 8 | 残存参照の分類 | **合格**（総195行。節名付きでSKILL.mdを指す残存は、本文に残る節への参照2件＋過去changelog1件のみ） |
| 9 | DDR差分0・spec影響範囲配下0 | **合格**（DDR 0行。spec配下1件は `check-base-sync.md:187` = 調査B-3の既知の現在状態小節 `### 呼び出し側の責務` への追従で、point-in-timeの書き換えではない） |
| 10 | 配布先に7ファイル | **合格**（`sync-assets.sh` → `mktemp -d`+`git init` へ配布し7ファイル実在） |
| 11 | `skill-reference` 7件 | **合格**（`search-frontmatter.sh --type skill-reference` matched=7。`--type skill` は8件のまま） |
| 12 | `bash -n` | **合格**（変更した7本すべてOK） |
| 13 | アンカー不一致0件 | **合格**（分割後の全 `.md` で残存アンカー3件はすべて `start-resume.md` 内で解決） |
| 14 | 相対参照の付け替え漏れ0件 | **合格**（元56行を所在ファイルごとに点検。別ファイル行きは下記の10件で、全て付け替え済み） |

## 例外リスト（「切り貼り以外で触らない」の例外＝参照の付け替え）

検証 #2-(ii) の旧側60行のうち、フロー表44行（参照列の追加）を除く**16行**が付け替えである。

| 場所 | 旧 | 新 |
|---|---|---|
| 本文33行目（担当列） | 下記「サブコマンド」節 | `references/start-resume.md`「サブコマンド」節 |
| 本文51-52行目（2行） | 詳細は下記「全体作業計画に必ず含めるフェーズ」 | 詳細は `references/planning.md`「同」 |
| 本文138行目（前提） | 上記「`gh`/`glab` CLI不在時のMCPフォールバック」節 | `references/mcp-fallback.md` |
| start-resume.md 17行目 | アンカー `[…](#ghglab-cli不在時のmcpフォールバック)` | `references/mcp-fallback.md`（＋再掲注記2行を追加） |
| start-resume.md 62-63行目 | 上記「PR/MR作成・マージの担当」節 | `` `.claude/skills/issue-mr-flow/SKILL.md` ``「同」節 |
| start-resume.md 82-83行目 | 下記＋アンカー `[計画・レポートのHTMLビュー](#…)` | `references/deliverables.md`「同」節（「下記」を除去） |
| start-resume.md 121行目 | 下記「PR作成後のdefaultブランチ追従（監視）」節 | `references/base-branch-followup.md`「同」節 |
| planning.md 132行目 | 下記「レビュー依頼メッセージ」節 | `references/review-loop.md`「同」節 |
| planning.md 248行目 | 下記「defaultブランチとのコンフリクト検知・解消」 | `references/base-branch-followup.md`「同」 |
| review-loop.md 90行目 | 上記「計画と実施結果の分離」 | `references/deliverables.md`「同」 |
| review-loop.md 262行目 | 下記「3. サブコマンドごとの読み替え」 | `references/mcp-fallback.md`「同」 |
| phase5-close.md 107-108行目 | 上記「`gh`/`glab` CLI不在時のMCPフォールバック」節 | `references/mcp-fallback.md`「同」節 |
| phase5-close.md 144行目 | 上記「計画・レポートのHTMLビュー」 | `references/deliverables.md`「同」 |
| phase5-close.md 292-293行目 | 上記「PR/MR作成・マージの担当」節 | `` `.claude/skills/issue-mr-flow/SKILL.md` ``「同」節 |

（表の行数と16行の差は、複数行にまたがる付け替えが旧側で2行に数えられるため。）

**追加分**（書き換えではなく新規）: 各 `references/*.md` の frontmatter（7行×7）＋H1＋空行、
`review-loop.md` の導入H2ブロック（7行）、`start-resume.md` の再掲注記（2行）、本文の
「旧節名→新しい場所の対応表」（見出し＋前文＋表27行）、フロー表の参照列。

## 検証 #3 の非節名7件の判断

| 抽出された「…」 | 判断 |
|---|---|
| `.claude/…SKILL.md` を読み直すこと | hookが注入する見出し。SKILL.mdの節ではない（hookの文面は変えない設計） |
| flow-idが1つ進むごとに、必ず`HANDOFF.md`を更新する | 手順の引用句。`references/planning.md` にあり「計画の2階層構造」行で辿れる |
| 作業開始・再開時のベースブランチ追従確認（issue #67） | 接尾辞付きの節名。対応表は接尾辞を省いて掲載（表の前文に明記した） |
| 既にブランチがあるかの確認／見つからない場合（新規作成） | `start` の手順名。「`start`」行で辿れる |
| 種別を複数併記する場合／分ける場合 | 小節名。対応表の「計画の2階層構造」行へ**包含を明記**した |
| 調査を実施 | フロー表2-6の語句。フロー表は本文に残る |

## 計画からの逸脱・想定と異なった点

1. **検証#2-(i) の期待値を8→9へ訂正した**（対応表自身のH2を数え漏れていた。作業3で対応表を
   足す以上、H2が1つ増えるのは計画時点で確定していた）。
2. **導入H2の位置は「H1の直後」ではなく「`### comments` の直前」にした。** 実際の切り出し結果は
   H2「敵対的レビューの位置づけ」（元417行）が先頭に来るため、H1直後に置くと今度は導入H2が
   位置づけ節を飲み込む。H3群の直前に置けば計画の目的（H1→H3の飛び防止・前提の再掲）は満たされる。
3. **本文のバイト数は27,349で「概ね25,000」を9%超過**（検証#1）。超過分は対応表（作業3）で、
   受け入れ条件#1の単位（500行以内）は満たす。
4. **検証#9-b の機械判定は1件を検出したが誤検出ではなく既知の例外**（`check-base-sync.md` の
   `## 影響範囲` 内の現在状態小節。調査B-3で「行番号による線引きが使えない」根拠にした実物）。
5. **参照列の全42行の割り当て**は次のとおり: 人間担当の行（1-1/1-5/2-3/2-8/3-3/3-8/4-3/4-8/5-6）と
   1-6 は `—`。開始系（1-2/1-3）は `start-resume.md`（1-3は`base-branch-followup.md`併記）。
   計画作成（1-4/2-1/3-1/4-1）は `planning.md`＋`deliverables.md`。commit/push・コメント対応・
   describe（x-2/x-4/x-5/x-7/x-10）は `review-loop.md`。実施（2-6は`planning.md`併記、3-6/4-6）は
   `deliverables.md`。結果修正（2-9/3-9/4-9）は `review-loop.md`＋`deliverables.md`。
   5-1は`base-branch-followup.md`、5-2〜5-5は`phase5-close.md`（5-3は`deliverables.md`併記）。

## 残課題

- **配布物に `index.jsonl`（生成物）が混入する**（`sync-assets.sh` が `cp -R` でコピーするため、
  作業ツリーに生成済みの `index.jsonl` が全ディレクトリ分そのまま配布される）。本issue以前からの
  既存挙動で、`references/` に限らない。**別issue候補**（`install-to-project.sh` の破壊的既定と
  合わせて起票を検討）。
- `.gemini/` 側のリンク動作は本環境では未確認（フェーズ4で扱いを決める。計画のスコープ外表）。
- `.claude/rules/directory-structure.md` の `references/` 行「（現時点で実例なし）」の更新は
  フェーズ4で行う（全体作業計画の記載どおり）。
