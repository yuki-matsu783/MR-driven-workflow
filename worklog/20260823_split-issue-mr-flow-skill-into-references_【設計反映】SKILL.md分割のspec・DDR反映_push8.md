---
title: worklog 20260823 SKILL.md分割のspec・DDR反映（push8）
type: log
description: issue #160 フェーズ4（設計反映）の試行錯誤ログ
tags: [worklog, issue-mr-flow, phase4]
keywords: [設計反映, spec, DDR, i0160-01, issue-mr-workflow, generate-ddr-list]
---

# worklog: SKILL.md分割のspec・DDR反映（issue #160 フェーズ4）

## flow-id 4-1（個別反映計画）

- `plans/【設計反映】SKILL.md分割のspec・DDR反映.md`（＋同名`.html`）を作成。
- 反映対象は A: `issue-mr-workflow.md`（hook節の更新＋影響範囲の新規エントリ）、
  B: `update-handoff-progress.md`（ROW_RE複製の注意）、C: DDR `i0160-01` 新規、
  D: `generate-ddr-list.sh` によるREADME再生成、の4点。
- フェーズ3で前倒し済みの項目（frontmatter type表・directory-structure.md・index.md）は
  対象から除外した（再変更しない）。

## 敵対的レビュー（フェーズ4・1回目=計画）と反映

- 13件検出（major 6 / minor 7）。カウンタ increment → 1/3。投稿9件・報告のみ4件。
- 全13件を計画へ反映した。主な変更:
  - 「反映元と洗い出しの対応表」節を新設（reports 2本＋全体計画から洗い出し、
    反映する/済み/追加作業なし/別issue引き継ぎ を明示）。
  - 変更対象へ E: `.claude/VERSION` 0.2.0→0.3.0（MINOR。distribution-assets.md が 4-6 と定める。
    非対話環境のため適用＋HANDOFF記録の方針）と F: hookコメントの「1000行超」更新を追加。
  - A-0（コンポーネント構成ツリー）・A-1への表側の維持責任・A-3への実測バイト値更新・
    B-2（影響範囲エントリ）・C-2（i0113-01 の note）を追加。
  - 検証を8項目へ改訂: `base="$(git merge-base origin/main HEAD)"` で分岐点固定、
    `.claude/` 全体の巻き添え確認、`generate-ddr-list.sh --check`（終了コード0）、
    md/html同期の機械判定（見出し一覧突き合わせ・プレースホルダ・外部参照）。
  - HTMLを再生成（goal/approach等のid・目次を復元し、mdと`##`/`<h2>`が一致する構成へ）。
- 事実確認: `generate-ddr-list.sh --check` は実在（終了コード0/2）。`setup-gemini-links.sh` は
  `skills` をディレクトリ単位でリンクするため references/ に追加作業は不要。

## mainのマージ（PR #157: 43ステップ化・.gemini生成物化・未返信スレッド管理）

- mainが同じSKILL.md本文へ大規模変更を入れたためコンフリクト6ファイル
  （SKILL.md / HANDOFF.md / issue-mr-workflow.md / docs-workflow.md / git-workflow.md /
  Provider.sh）。解消方針: **自ブランチ=配置の変更、main=内容の変更**なので、mainの内容を
  分割後の構成（本文＋references/）へ移植する。
- 機械解消: スクリプトで「theirs（main）を採ってから、切り出し済み節への参照を
  `references/<file>.md`「節名」へ再置換」する形で4ファイルを解消（節名→参照ファイルの
  対応は SKILL.md の対応表と同じもの）。
- SKILL.md: 自分の43行表（参照列付き）を残し、mainの行変更を移植——x-4/x-9 の6行へ
  「レビューOK」ゲーティング文（参照先は `references/review-loop.md` へ付け替え）、
  新5-3（gemini変換同期）行の挿入、5-4〜5-7の繰り下げ（参照列は phase5-close.md 等）。
- references/ 7本へmainの節変更を移植: planning.md（1周完了の2条件・ヘッダ7行・43ステップ）、
  review-loop.md（位置づけ表の未返信の記録行・comments手順2/5のブロック・完了合図(3)と実例）、
  phase5-close.md（新節「`.claude/` → `.gemini/` の変換同期（flow-id 5-3）」・全繰り下げ）、
  deliverables.md / start-resume.md / mcp-fallback.md / base-branch-followup.md（番号繰り下げ）。
- 追随修正: test_session_start.sh の実データ検証 42→43行、update-handoff-progress.sh の
  hintメッセージと plans.template.html の節参照を references/ へ、フェーズ4計画md/htmlの
  flow-id 繰り下げ（統括 5-3→5-4 等）。SKILL.md の対応表へ 43行・5-5改名・gemini節の3行を反映。
- 検証: マーカー0・`bash -n` OK・全17テスト failures=0（ROW_RE等式テスト含む）・
  `generate-ddr-list.sh` 差分なし・DDR削除0。マージコミット d6a7c7e（push 10回目）。
- `sync-gemini-assets.sh --check` は非0（＝`.claude/`変更が`.gemini/`未反映）だが、これは
  フロー設計どおり flow-id 5-3 で同期する（毎コミット同期はしない。phase5-close.md 参照）。

## flow-id 4-6: 反映A〜Fの実施

- A-0〜A-4 / B-1〜B-2 / C-1〜C-2 / D / E / F を計画どおり実施（詳細は反映レポートが正文）。
- 反映はマージ後の姿（43ステップ・新番号）を前提に読み替えた。A-1へは
  「mcp-fallback.md は参照列で指さない」設計も追記（マージで本文に確定した記述と整合させるため）。
- 実測やり直し: 指示文は627〜857バイト（参照3本の最大ケースを含む）。
- 検証8項目すべて合格。検証5の再実行で、マージ解消時に `HANDOFF.md` の `## 次にやること`
  見出しを誤って落としていたことを実データ回帰テストが2件の失敗として検出した
  （Editの置換で見出し行を new_string へ入れ忘れた）。修正して全緑（passed=1132）。
  ——実データ回帰テストを入れた判断（フェーズ3・敵対的レビュー指摘）が早速効いた実例。

## 敵対的レビュー（フェーズ4・2回目=結果）と対応

- 11件検出（minor 9 / nit 2。high 10 / medium 1）。マトリクス選別で投稿8件・報告のみ3件。
- 大きい対応3つ: (1) `distribution-assets.md`「増分の決め方」へ非対話的セッションの例外を
  明文化（規約と先例の矛盾を残さない。0.3.0は維持）、(2) `resolve-conflict/SKILL.md` へ
  類型F「配置の変更 vs 上流の内容変更」を追加（今回のマージ解消の手順・検証を一般化）、
  (3) バイト実測のやり直し——hookが渡すのは「現在地 flow-id … の実行前に開く参照: 」を含む
  組み立て済みの1行で、参照ファイル名だけを渡すと約50バイト測り漏らす（857→919）。
- DDR i0160-01 の「- ステータス: 承認済み」行は79件中唯一の独自形式だったため削除
  （statusの正はfrontmatter。マージ前なので本文を直せる）。i0113-01整合の段落は
  「関連する既存の決定」節へ分離し、却下案は5件に。レポートのサマリ・詳細・HTMLを統一。
- HANDOFF 4-2 の mark-done 漏れは、current_flow_id_to_reply が誤って 4-2 を指す実害付きで
  検出された（機械化が表の正確さに依存する実例として指摘8に記録）。

## mainのPR #154（manifest配布方式）取り込み（flow-id 5-1で検知）

- 5-1 のコンフリクト検知で main が b8a1b58（PR #154: 配布のmanifest方式化・
  `agent-common.md` 分離）まで進んでいたため、`git merge` で取り込んだ。
- コンフリクト3件はいずれも**逆向きの類型F**（上流=配置の変更、自ブランチ=内容の変更）として解消:
  - `AGENTS.md`: mainの `@./.claude/rules/agent-common.md` import行を採り、
    自ブランチが持っていた参照の付け替え3箇所（`references/start-resume.md`「`start`」節・
    `references/planning.md`「計画の2階層構造」・`references/mcp-fallback.md`「MCPフォールバック」節）を
    移動先の `agent-common.md` へ手で移植した。
  - `.claude/rules/directory-structure.md`: バンドルリソース表はmainの `scripts/` 行例
    （`install-to-project.sh`）＋自ブランチの `references/` 行（7本, issue #160）の両取り。
  - `index.md`: mainのスキル一覧拡充＋自ブランチの references/ サブ項目を併記。
- main側の変更ファイルで移動済み節を指していた1箇所を付け替え:
  `commit/SKILL.md` の `ai-asset` 行が `SKILL.md` の `【AIアセット作成】` 定義を指していた →
  `references/planning.md` へ。
- `apply-mr-workflow-to-project/assets/` に残っていた旧 `sync-assets.sh` のビルド生成物
  （untracked）が新テストの「sourceを持つエントリが複数ファイルに一致」失敗を誘発したため削除。
  もう1つの原因はマージ途中のindexがコンフリクトファイルを3ステージ持ち `git ls-files` が
  重複を返すことで、解消ファイルの `git add` で収束した。
- 検証: 全テスト bash 18本 passed=1259 failures=0・perl 2本 OK・マーカーなし・
  DDR一覧79件最新・`check-dist-coverage.sh` 414/414 OK（references/ 7本も配布対象に含まれる）。
