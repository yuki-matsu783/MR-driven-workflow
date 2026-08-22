---
title: AIアセット配布のmanifest方式への作り直しと層分け定義（issue #26）
type: plan
description: 配布アセットを4層（core/seed/merge/local）へ分類し、適用元コミットSHAとsha256を記録するmanifest方式へ配布機構を作り直す全体作業計画
tags: [plan, distribution, manifest, workflow]
keywords: [manifest, 層分け, core, seed, merge, local, install-to-project, sync-assets, asset-manifest, setup-gemini-links, AGENTS, 収穫, 逆輸入]
---

# 全体作業計画: AIアセット配布のmanifest方式への作り直し（issue #26）

- issue: https://github.com/yuki-matsu783/MR-driven-workflow/issues/26
- ブランチ: `claude/ai-asset-manifest-distribution-u2gn22`

## このissueで達成すること

配布先で加えられた改善を本家へ収穫（逆輸入）できる双方向プロセスの**第1弾**として、収穫の前提と
なる次の2つを整備し、`apply-mr-workflow-to-project` スキルをその方式へ作り直す。

1. **どの版を適用したかの記録**（`.claude/.asset-manifest.json`）＝ 3-wayマージの基準点（base）
2. **アセットの層分け定義**（`core` / `seed` / `merge` / `local`）

**収穫スキル自体は本issueの範囲外**（後続issueで扱う）。

## スコープ判定: 分割しない

`.claude/skills/issue-mr-flow/SKILL.md`「issueが大きすぎる場合の分割提案」の基準で判定した。

- **主トリガー（並列列挙構造）には該当する**ように見える（受け入れ条件が10項目並ぶ）。
- しかし**「分割しない条件」の「横断的変更」に当たる**ため、分割しない。判定の一問
  「各項目が単独でマージされても、システムが壊れないか」に対し、**壊れる**からである。
  - 層分け定義ファイルだけをマージしても、それを読むインストーラが無ければ何も起きない。
  - manifest生成だけをマージしても、層の規則が無ければ何を記録すべきか決まらない。
  - `AGENTS.md` の分割は、`AGENTS.md` を `core` と `seed` のどちらにも置けないという
    **層分けの前提**であり、層分けと同時に入らないと `AGENTS.md` の扱いが宙に浮く。
- 単独で切り出せるのは `setup-gemini-links.sh` のフォールバック追加だけだが、これは1関数の
  変更であり、「分割コストが本体を上回る」に該当する。

この判断と理由は `HANDOFF.md`「判断を迷った内容」にも残す（同じ議論を蒸し返さないため）。

## 前提の更新（issueコメント5件の反映）

issue本文は起票時点（2026-08-18）のもので、その後のマージで前提が動いている。**着手時は
以下を正とする**。

| # | 通知元 | 反映すること |
|---|---|---|
| 1 | PR #80（issue #77） | スキル2件（`adversarial-review` / `review-points`）・エージェント1件・スクリプト2件が増えた。**`REVIEW-POINTS.md` は `.claude/` の外側（ルート・`plans/`・`reports/`）にもあり、「本家が初期セットを配るが、中身は配布先が育てる」性質**のため層の扱いに検討が要る |
| 2 | PR #102（issue #28） | `cleanup-task.sh` とその単体テストが増えた。**「消さずに残すもの」がスクリプト内定数**（`worklog/TEMPLATE.md` / `REVIEW-POINTS.md`）である点に注意 |
| 3 | PR #104（issue #38） | `doc-search` スキルが増えた。`AGENTS.md` の共通ルールが1項目増えた（ドキュメント探索） |
| 4 | PR #136（issue #33） | 3資産の層が根拠つきで確定済み（PR/MRテンプレ=`seed`、`.gitattributes`=`merge`、`.claude/VERSION`=`core`）。**`.gitattributes` の行追記が `merge` 層の先行実装**であり、満たすべき4性質（冪等／行全体一致／CR除去／末尾改行）が既に揃っている。**「配る行の定義をどこが持つか」は層分け定義でも同じ論点になる**。あわせて既存欠陥4件が未修正のまま記録されている |
| 5 | PR #137（issue #133） | DDR識別子が `i<issue番号>-<枝番>` へ変更。issue本文の「DDR 0017」は現在 `i0000-13` |

## フェーズ2〈調査〉

**実施する。** 層分けは「現在リポジトリに何があるか」の全数把握が無いと定義できず、既存欠陥
（通知#4の4件）の再現条件も確かめる必要があるため。

調査項目（詳細は flow-id 2-1 の個別調査計画で確定する）:

1. **配布対象パスの全数棚卸し**。`.claude/` 配下・ルート直下・`.github/` `.gitlab/` の全ファイルを
   列挙し、4層のどれかへ漏れなく分類できるかを確かめる。**どの層にも入らないパスが残らないこと**
   （分類の網羅性）を検証の軸にする。
2. **`REVIEW-POINTS.md` の層**（通知#1の宙吊り論点）。`core` だと配布先の観点が消え、対象外だと
   初期セットが配られない。第5の層を作るか、`seed` で足りるかを決める。
3. **層分け定義の置き場所と形式**。通知#4の「配る行の定義をどこが持つか」と同じ論点。
   定義ファイル1枚に集約するか、`.gitattributes` のように各ファイル自身が持つか。
4. **manifestの記録項目**と、それで受け入れ条件「適用後に変更されたかどうかを判定できる」が
   満たせるかの確認。
5. **既存欠陥4件の再現**（`.gitignore` 追記の非冪等・部分一致・行の不一致・`HAS_WARNED` の消失）。
   作り直しで自然に消えるのか、明示的に対処が要るのかを切り分ける。
6. **`AGENTS.md` の分割線**。どこまでが共通ルール（本家所有）で、どこからがプロジェクト概要
   （配布先所有）か。`CLAUDE.md` / `GEMINI.md` の `@import` 記法が `.claude/rules/` 配下の
   ファイルに対しても機能するかの確認を含む。
7. **`.skill` パッケージ廃止の影響範囲**。参照箇所を「書き換えが要る現状の説明」と
   「書き換えてはいけない過去の記録（DDR本文・specのchangelog）」に分ける。
   **`DEVELOPERS.md` は確認対象ではなく書き換え対象**（受け入れ条件10の後半）。

## フェーズ3〈作業〉

調査結果をもとに確定するが、現時点の見込みは次のとおり。個別作業計画は flow-id 3-1 で作る。

| 種別 | 内容（見込み） |
|---|---|
| `【設計】` | 層分け定義ファイルのスキーマ、manifestのスキーマ、インストーラの処理順序 |
| `【実装】` | 層分け定義ファイルの新規作成／`install-to-project.sh` の作り直し（層ごとの配置・manifest生成・**dirty中断ガード**・再適用時の警告）／`setup-gemini-links.sh` の実体コピーフォールバック／`AGENTS.md` の分割／`sync-assets.sh` 削除 |
| `【テスト】` | `test_install_to_project.sh` の作り直し（受け入れ条件の各項目に対応するケース）／**現行テストの表明の棚卸しと引き継ぎ**（受け入れ条件には現れないが守られている保証。PR/MRテンプレートの見出しが `describe` の生成物と一致する／`.gitattributes` の行追記が何度適用しても増えない（配布先がCRLFの場合を含む）／`.claude/VERSION` の更新が `.bak` と警告を生まない、等）／`setup-gemini-links.sh` のフォールバック検証 |
| `【AIアセット作成】` | `apply-mr-workflow-to-project/SKILL.md` の全面改訂（`.skill` 前提の記述を削除し新方式へ）／**`DEVELOPERS.md` の書き換え**（`sync-assets.sh` 実行 → `package_skill.cjs` → `gemini skills install` の手順を新方式へ差し替える。受け入れ条件10の後半。フェーズ4ではなくここで行う）／`ai-asset:` prefix 運用規約の追加 |

**`【テスト】`の作り直しでは、旧テストを新実装に対しても流して差分を見る**（受け入れ条件に対応するケースだけで書き直すと、上記の既存の保証が無言で失われるため）。

## フェーズ4〈反映〉

**反映対象は flow-id 4-1 で洗い出す**（この時点では確定させない）。見込みの候補のみ挙げる。

- `【設計反映】`: `.claude/docs/spec/distribution-assets.md` の更新（配布経路の節が旧方式のまま）、
  配布方式の新規spec、方式選定のDDR（git subtree / Claude Code plugin配布 / 差分をAIが都度判断する案
  の却下理由）、`generate-ddr-list.sh` の再実行
- `【AIアセット反映】`: `.claude/rules/` への `ai-asset:` prefix 規約、`directory-structure.md` の
  ツリー更新、`.claude/VERSION` の増分提案
- `【実装反映】`: フェーズ3で持ち越した不具合があれば

## 進め方（このセッションの特記事項）

- **ブランチ名がリポジトリの命名規則（`feature-<issue番号>-<slug>`）と一致しない。**
  ハーネスが `claude/ai-asset-manifest-distribution-u2gn22` を指定しているため、そちらに従う。
- **人間のレビュー（flow-id 2-3/2-8/3-3/3-8/4-3/4-8）の代わりに、各フェーズの結果確認で
  敵対的レビュー（`adversarial-review` スキル）を実施する**（ユーザーの明示指示）。
  各フェーズ最大3回の制限は従来どおり。
- 全体作業計画はPlanモード（planツール）ではなくWrite/Editで作成した。ハーネスがPlanモードを
  終了した状態でセッションを開始しており、再入するとユーザーの応答待ちで止まるため。
