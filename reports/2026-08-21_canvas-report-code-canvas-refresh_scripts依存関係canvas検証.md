---
title: canvas-report新テンプレートの実データ検証（scripts依存関係）
type: report
description: issue #141で全面刷新したcanvas-reportテンプレートを、.claude/scripts・.claude/hooks配下の実依存関係データで生成し、ブラウザ実機（Playwright+Chromium）で受け入れ条件を検証した結果。
tags: [canvas-report, verification, playwright]
keywords: [Code Canvas, セマンティックズーム, 自動レイアウト, エッジ集約, 検証, Playwright, Chromium, 受け入れ条件]
---

# canvas-report新テンプレートの実データ検証（scripts依存関係）

issue #141「canvas-reportテンプレートを階層セマンティックズーム対応のCode Canvas形式へ
全面刷新する」の作業結果。個別作業計画は
`plans/【設計】【実装】【テスト】canvas-reportテンプレート全面刷新.md`。
**同名の `.html` は本検証で生成したサンプル成果物**（scriptsの依存関係を新テンプレートで
描いたもの）であり、この検証結果自体の図解ではない（このmdが結果の正文）。

## 実施した内容

1. `.claude/skills/canvas-report/templates/canvas-report.html`（468行）を全面刷新した
   （データ部＋エンジン部の自己完結HTML。敵対的レビュー対応後の実測で1,542行。`wc -l`）。
2. `.claude/skills/canvas-report/SKILL.md` を新データモデル・抽出手順・規模指針・mermaidの
   位置づけ変更に合わせて書き換えた。
3. SKILL.mdの抽出手順どおりに `.claude/hooks/`・`.claude/scripts/` の実依存関係を抽出し、
   同名 `.html` を生成した（レイヤ5・クラス29・メンバ41・エッジ38本。ノード総数70で
   受け入れ条件の「40ノード規模」を満たす。変更バッジはmainの直近3コミットのnumstat実測値）。
4. Playwright＋同梱Chromium（headless）でブラウザ実機検証を行った。

## 主要な設計判断

- **エンジンの自己完結化（Tailwind CDN非依存）**: 旧版の不具合5（`animate-[...]` が動かない）・
  6（`z-25` が存在しない）はTailwind CDN依存が直接原因だった。加えて本リモート実行環境では
  CDNがプロキシで遮断されており（実測: `cdn.tailwindcss.com` へ到達不可）、CDN依存のままでは
  ブラウザ検証自体が成立しない。canvas形式に限りスタイルを自前CSSにし、外部依存を任意の
  mermaid.js 1本へ絞った（オフライン時はソース文字列表示に退避）。
- **メンバはフラット配列＋parent参照**: ネスト記法では循環parentが原理的に書けず、
  受け入れ条件「循環する親子関係の検出」がデータ表現として成立しないため。
- **レイアウトのfootprintはL1（メンバ一覧）基準**: L2のコード片・手動展開によるはみ出しは
  重なりを許容し、最前面＋他の減光で読みやすさを保つ（issueの除外事項
  「展開時の周囲再レイアウト」に対応する判断）。

## 検証結果

### テンプレート同梱サンプル（架空の注文サービス）: 34/34 pass

`verify_template.js`（Playwright）による機械検証。主な項目:

| 受け入れ条件 | 結果 |
|---|---|
| `List<String>` を含むラベルが文字として描画（無エスケープ挿入なし） | ok |
| FITで全クラスがビューポート内に収まる（外接矩形から算出） | ok |
| ズームのみで L0（レイヤ俯瞰）→ L1（クラス＋メンバ一覧）→ L2（コード片）へ切替 | ok |
| L2のコード片に行番号が付く | ok |
| L0でメンバ単位エッジが（クラスペア,種別）へ集約され本数が減る | ok |
| ▾/▸トグルで折りたたみ⇄展開、エッジ端点が張り替わる、展開ノードが最前面 | ok |
| 変更バッジ +12/−3 と状態色（modified=amber）が表示される | ok |
| 検索候補表示→Enterでメンバへジャンプ・選択される | ok |
| 選択ノードの上流/下流エッジ色分け＋無関係エッジの減光 | ok |
| レイヤ・関係種別トグルでノード・エッジが消える | ok |
| ノードの上からパンでき、パン後にクリック選択が誤発火しない | ok |
| 小デルタwheel=パン（トラックパッド）、Ctrl+wheel=ズーム | ok |
| ミニマップクリックでジャンプ（ヘッダ64pxずれなし。minimap自身の矩形基準） | ok |
| SVGがworldサイズに追従し overflow visible（固定1700×1000の撤廃） | ok |
| クラス箱の重なりなし | ok |
| コンソールエラーなし | ok |

### 不正データ注入版: 7/7 pass

未定義ID参照・循環parent（A⇄B）・必須項目欠落（label/layer/id）・未知kind・重複id・
未定義layerを含むデータで、**赤字のエラーパネルに全類型が列挙され、妥当なノードだけで
描画が続行される**ことを確認した。

### 実データ版（このディレクトリの同名.html）: 16/16 pass（敵対的レビュー対応後の再実行）

| 項目 | 結果 |
|---|---|
| クラス29＋メンバ41＝70ノードが `x`/`y` 手打ちなしで重なりなく配置 | ok |
| world 1560×2997（SVGのwidth/height属性の実測値。旧固定1000超のy領域にもエッジ描画） | ok |
| 検索「sync_usage_state」でL2のコード片までジャンプ | ok |
| ジャンプ着地精度: 選択メンバ行が画面中央±150px以内（LOD切替後の高さで算出） | ok |
| 選択メンバの上流（amber）ハイライト | ok |
| L1→L0でエッジ38本→33本へ集約 | ok |
| 実変更バッジ（CommandPosition.sh +590 等。mainのHEAD~3..HEADのnumstat） | ok |
| path:lines が `meta.repoUrl` でGitHub blobリンク化 | ok |
| コンソールエラー・データエラーパネルなし | ok |

スクリーンショット（L0俯瞰・L2コード片・ハイライト・エラーパネル）は検証時に取得して
目視確認した（テンポラリのため成果物には含めない。再取得は下記コマンドで可能）。

### 再現手順

```
node verify_template.js .claude/skills/canvas-report/templates/canvas-report.html
node verify_report.js reports/2026-08-21_..._scripts依存関係canvas検証.html
```

（検証スクリプトはセッションのscratchpadに作成。使い捨てのためリポジトリには含めない。
`.claude/rules/ai-command-style.md`「切り出し先の選び方」の判断による）

## 旧版の不具合1〜12との対応

| # | 旧不具合 | 新実装での解消方法 |
|---|---|---|
| 1 | `innerHTML` 無エスケープ | 全データ文字列を `textContent` で挿入（検証: `List<String>`） |
| 2 | world/SVG固定1700×1000 | 内容の外接矩形から動的算出＋ `overflow: visible` |
| 3 | 矢印がカード下に隠れる | 端点をノード境界（クラス箱の辺・メンバ行の端）に取る |
| 4 | 矢印が単色固定 | 色ごとに `<marker>` を動的生成（ハイライト色にも追従） |
| 5 | 破線アニメーション不動作 | 実CSS `@keyframes edgeflow`（Tailwind任意値クラス廃止） |
| 6 | `z-25` が存在しない | 自前CSSのz-index体系（backdrop 62 / panel 63 / errors 90） |
| 7 | FITが固定値リセット | 可視ノードの外接矩形からscale/panを算出 |
| 8 | ミニマップ64pxずれ | minimap自身の `getBoundingClientRect` 基準で座標変換 |
| 9 | エッジラベル未描画 | ホバーのツールチップで種別・本文・集約内訳を表示 |
| 10 | ノード上からパン不可 | pointerイベント＋移動閾値4pxでパンとクリックを両立 |
| 11 | mermaid多重描画 | 描画済みSVGキャッシュ＋busyガード＋await |
| 12 | トラックパッド非対応 | Ctrl+wheel=ズーム、小デルタwheel=パンのヒューリスティック（タッチ・ピンチは初版対象外） |

## 敵対的レビュー（1回目）と対応

`adversarial-review` スキルによりフェーズ3対象（diff全体）で実施（14件検出、うち10件を
PR #150へインライン投稿・4件は報告のみ）。**全14件へ対応し、上記の全検証を再実行して
パスを確認済み**。主な対応:

- **jumpToのLOD順序**（major）: scale確定→`applyLevels()`→行位置測定の順へ修正し、
  折りたたみoverrideも解除するようにした。着地精度の機械検証（±150px）を追加。
- **レイアウトの実測詰め直し**（major）: DOM生成後に `measureHeights()` でoffsetHeightを
  一括測定し、実測値で `layout()` をやり直す2パス構成へ変更（ラベル折り返しによる
  見積もり超過での重なりを防止）。`fit()` も同様にLOD切替後の高さで取り直す2パス化。
- **エスケープ仕様の明確化**（major）: エンジンの自動エスケープはDOM挿入時のみ効く。
  `</script`（→`<\/script`）とJS文字列のクォート・バックスラッシュは生成側の責務として
  SKILL.md・テンプレート冒頭コメントに明記した。
- **HANDOFF進捗表**（major）: 41ステップの進捗表を記入し、以降の更新を
  `update-handoff-progress.sh` で行える状態にした。
- そのほか: メンバ`desc`の仕様削除、plansへの実装後変更の追記、本mdの実測値修正
  （行数1,542・world 1560×2997）、サンプルHTMLのエッジ誤り修正
  （`get_vcs_access_mode` の呼び出し元は `build_context`）、未使用mermaidタグと
  雛形コメントの除去（SKILL.md手順5へ再発防止の手順を追記）、minimapの `pointercancel` 対応。
- **反証により棄却した指摘1件**: 「world幅1560はWRAP_W定数の書き写しで実際は1510」は、
  再現計算が座標上書きパスの `cls.x + CLASS_W + WORLD_PAD` 項を見落としたもので、
  ブラウザ実測（SVGのwidth属性）は修正前後とも1560だった（1560はWRAP_Wとの偶然の一致）。

## 既知の限界（初版スコープ）

- タッチ・ピンチ操作、URL状態保存、描画カリング、展開時の周囲再レイアウト、
  シンタックスハイライト等はissue #141の「初版に含めない」のとおり未対応。
- L2でコード片が展開されるとクラス箱がfootprint（L1基準）を越えて下方向へ伸び、
  下の帯と視覚的に重なることがある。展開ノードの最前面表示＋他ノードの減光で
  読み分けは可能（設計判断どおり）。
- マウスホイールとトラックパッドの判別はヒューリスティック（`deltaMode===0` かつ
  |deltaY|<40 または deltaX≠0 をパンとみなす）のため、トラックパッドの高速フリックは
  ズームと解釈されることがある。
