---
title: 【設計】【実装】【テスト】canvas-reportテンプレート全面刷新
type: plan
description: issue #141の個別作業計画。新テンプレートのデータモデル・エンジン設計・実装範囲・検証手順を定める。
tags: [canvas-report, template, design, plan]
keywords: [データモデル, レイヤ, クラス, メンバ, 自動レイアウト, LOD, エッジ集約, エスケープ, バリデーション, Playwright]
---

# 【設計】【実装】【テスト】canvas-reportテンプレート全面刷新

全体作業計画: `plans/canvas-report-code-canvas-refresh.md`（issue #141）。
種別を併記するのは、非対話セッションで合意を1回で取る前提のため（設計・実装・テストを
分けても人間のレビュー往復を挟めない）。

## 1. データモデル（設計）

データ定義とエンジンを分離する。生成側が書くのは以下の3つ＋メタ情報のみで、**座標・色クラス・
HTML断片は一切書かない**（全文字列はエンジンが `textContent` ベースで自動エスケープする）。

```js
const CANVAS_DATA = {
  meta: {
    title: '…', subtitle: '…',
    repoUrl: 'https://github.com/<o>/<r>/blob/<ref>/',   // 任意。あればpath表示をリンク化
  },
  layers: [
    { id: 'hooks', label: 'Claude Code hooks', desc: '…' },  // 配列順＝上から下への帯の並び
  ],
  nodes: [
    // クラスノード（parent無し・layer必須）
    { id: 'Provider', layer: 'vcs', label: 'Provider.sh', path: '.claude/scripts/src/vcs/Provider.sh',
      desc: '…', change: { status: 'modified', add: 12, del: 3 },   // change/desc/path/detail/mermaidは任意
      detail: '長文の補足（プレーンテキスト）', mermaid: 'graph LR…' },
    // メンバノード（parent＝クラスid・layer不要）
    { id: 'Provider.get_issue', parent: 'Provider', label: 'get_issue <n>', lines: '120-145',
      code: '…複数行のコード片…', codeStart: 120, change: { status: 'added', add: 26 } },
  ],
  edges: [
    // from/toはクラスidまたはメンバid。kindはEDGE_KINDSのキー
    { from: 'Provider.get_issue', to: 'Github.github_get_issue', kind: 'call', label: '…' },
  ],
};
```

- 階層は `レイヤ > クラス > メンバ` の3層固定。メンバは**フラットなnodes配列に `parent` 参照で
  書く**（ネスト記法にしない）。理由: 生成側のjq/スクリプトで扱いやすく、受け入れ条件の
  「循環する親子関係の検出」がデータ表現として成立するため。
- 関係種別 `EDGE_KINDS` は既定で `call`（呼び出し）/`extend`（実装・継承）/`di`（DI・source）/
  `data`（データアクセス）/`other` の5種。キー・色・線種・和名はデータ側で上書き可能。
- 変更状態 `change.status` は `added`/`modified`/`deleted` の3値。`add`/`del` は行数バッジ用。

## 2. エンジン設計（設計）

自己完結HTML1枚（TailwindCSS CDN＋任意でmermaid CDN）。エンジン部は素のJSで、以下の構成。

> **追記（実装後の変更）**: 実装中にTailwindCSS CDN依存を撤廃し、スタイルを自前CSSの
> 自己完結へ変更した（検証環境でCDNがプロキシ遮断されており実機検証が成立しないこと、
> 旧不具合5・6の根本原因がTailwind依存だったことによる。経緯・却下案はDDR `i0141-01`、
> 結果は `reports/2026-08-21_…_scripts依存関係canvas検証.md`「主要な設計判断」参照）。
> 下表の「実在するz-indexクラスを使う」は「自前CSSのz-index体系で管理する」と読み替える。

| 節 | 責務 |
|---|---|
| validate | 重複id／未定義layer・parent・エッジ端点／親子の循環・深さ超過／必須項目欠落を検出し、**画面上の赤字パネル**へ列挙（黙って壊れない）。妥当な部分だけで描画は続行 |
| model | クラス・メンバ・エッジの解決（エッジ端点→クラス＋メンバへ正規化） |
| layout | レイヤ帯を縦に積む。帯内はbarycenter法（隣接レイヤの接続先の平均x）で列順を決め、行折返しで格子配置。**footprintはメンバ一覧表示時（LOD1）の高さで確保**する。`x`/`y` が明示されたノードのみ上書き |
| render | ノードはHTML div（`textContent`でエスケープ）、エッジはSVG path。SVG・worldのサイズは内容の外接矩形から動的算出（固定1700×1000の撤廃） |
| edges | 端点はノード境界（クラス箱の左右辺 or メンバ行の左右端）。両端のクラスが折りたたみ表示のときは**（クラスペア, kind）単位で1本へ集約し太さ＝本数**、展開時はメンバ行へ張り替え。多重エッジは法線方向オフセットで分離、自己ループは右側の弧。矢印マーカーは**色ごとに動的生成**（単色固定の撤廃）。ホバーでラベル（種別・本文・集約本数）をツールチップ表示。破線アニメーションは実CSS `@keyframes`（Tailwind任意値クラスに依存しない） |
| LOD | scale連動の3段階: L0=レイヤ俯瞰（クラスはチップ表示）→ L1=クラス箱＋メンバ行 → L2=メンバ行＋コード片（行番号つき、`path:lines` 表示、`meta.repoUrl` があればリンク）。クラス箱の▸/▾ボタンでズームと独立に折りたたみ/展開でき、展開ノードは最前面＋他を減光（**周囲の再レイアウトはしない**。issueの除外事項） |
| interaction | パン=ドラッグ（**ノード上からも可**。移動閾値4pxでクリックと区別）。ズーム=ホイール（Ctrl+ホイール=ピンチ相当、トラックパッドの2本指スクロール=パンのヒューリスティック対応。タッチは対象外）。クリックでノード選択→**上流・下流を方向別に色分け**ハイライト。`Esc`=解除、`f`=全体フィット、`/`=検索フォーカス |
| fit/minimap | FITは可視ノードの外接矩形から算出。ミニマップも動的境界で、自身の `getBoundingClientRect` 基準でジャンプ座標を計算（ヘッダ64pxずれの解消）。ズーム率を画面上に表示 |
| search/toggle | クラス名・メンバ名・パスの部分一致検索→候補リスト→選択でズームジャンプ。レイヤ・関係種別の表示トグル（非表示レイヤのノード・接続エッジを隠す） |
| detail | クラスの詳細（`detail`・`mermaid`）は右パネルに表示。mermaidは描画済みキャッシュ＋awaitで多重描画を防止。バックドロップは実在するz-indexクラスを使う |

## 3. 実装範囲

1. `.claude/skills/canvas-report/templates/canvas-report.html` — 同一パスで全面書き換え
   （旧版と併存させない）。冒頭コメントに使い方、データ部にモデル構成が分かる小さなサンプルを同梱。
2. `.claude/skills/canvas-report/SKILL.md` — データモデル・依存関係の抽出手順
   （bashスクリプト群からの `source`/関数呼び出しの抽出手順）・規模の指針（1枚〜40クラス）・
   mermaidの位置づけ（詳細パネル内の補足図へ降格）を書き換え。
3. サンプル実生成: `.claude/scripts/`・`.claude/hooks/` の実際の依存関係で
   `reports/2026-08-21_canvas-report-code-canvas-refresh_scripts依存関係canvas検証.html` を生成。
   正文は同名 `.md`。

## 4. 検証手順（テスト）

Playwright＋同梱Chromiumで、生成したサンプルと不正データ注入版に対して以下を機械的に確認し、
結果（スクリーンショット含む）を `reports/…canvas検証.md` へ記録する。

- [ ] コンソールエラーが無い
- [ ] `List<String>` 等 `<` を含むラベルが文字として表示される（DOM上にタグとして解釈されない）
- [ ] 旧固定サイズ1700×1000の外側にあるノード間のエッジが描画される
- [ ] FITで全ノードがビューポートに収まる
- [ ] ズームのみでL0→L1→L2（コード片）へ切り替わる
- [ ] クラス展開時にエッジ端点がメンバ行のY座標へ移動し、折りたたみで集約本数＝太さになる
- [ ] 変更バッジ（+N/-M）と状態色が表示される
- [ ] 検索でメンバ名を引いてジャンプできる
- [ ] レイヤ・関係種別トグルでノード・エッジが消える
- [ ] 未定義ID参照・循環parent・必須項目欠落を含むデータで赤字パネルが表示される
- [ ] データ側に `x`/`y` を書かず40ノード規模が重なりなく配置される（サンプル実データで確認）

## 5. やらないこと

issue「初版に含めない」の列挙どおり（タッチ・URL状態保存・カリング・展開時再レイアウト・
パンくず・フォーカス分離・シンタックスハイライト・シンボル追跡・循環依存検出・影響自動塗り・
before-after・物理演算・画像書き出し・a11y）。
