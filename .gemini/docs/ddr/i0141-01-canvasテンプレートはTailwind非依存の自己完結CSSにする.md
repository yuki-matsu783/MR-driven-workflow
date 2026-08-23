---
title: i0141-01. canvasテンプレートはTailwind非依存の自己完結CSSにする
type: ddr
description: canvas-reportテンプレート（Code Canvas形式）のエンジン・スタイルはTailwindCSS CDNに依存せず自前CSSで自己完結させ、外部依存を任意のmermaid.jsのみとする決定。
tags: [canvas-report, css, template]
keywords: [TailwindCSS, CDN, 自己完結, オフライン, 任意値クラス, z-index, keyframes, mermaid]
note: 'canvas形式をTailwind非依存にした決定は有効。ただし issue #54 で一覧・表形式のテンプレートも自己完結CSSになったため、「canvas形式だけが例外」という本文の前提は成り立たない。本文中の `templates/canvas-report.html` も当時のパスで、issue #54 で `assets/canvas-report.html` へ改名した。詳細は i0054-01'
---

# i0141-01. canvasテンプレートはTailwind非依存の自己完結CSSにする

issue #141（canvas-reportテンプレートのCode Canvas形式への全面刷新）での決定。

## 決定

`.claude/skills/canvas-report/templates/canvas-report.html` のスタイル・エンジンは**自前CSSで
自己完結**させ、外部依存は任意のmermaid.js（詳細パネルの補足図用。読み込めない場合はソース
文字列表示へ自動退避）のみとする。`reports/` 配下の**通常の一覧・表形式HTMLは引き続き
TailwindCSS CDN方式**であり、本決定はcanvas形式テンプレートに限る。

## 背景

- 旧テンプレートの表示不具合のうち2件はTailwind CDN依存が直接原因だった。
  - Tailwindは任意値クラス `animate-[dash_1.6s_linear_infinite]` に対応する `@keyframes` を
    CDN実行時に出力せず、破線の流れるアニメーションが一切動かない（issue #141 不具合5）。
  - `z-25` はTailwindに存在しないクラスで、詳細パネルのバックドロップの重なり順が効かない
    （同 不具合6）。ユーティリティクラスは**存在しない指定が黙って無視される**ため、この種の
    誤りは実行時まで気づけない。
- Claude Code on the webのリモート実行環境では外部CDNがプロキシで遮断されており（issue #141
  対応時に実測: `cdn.tailwindcss.com`・`cdn.jsdelivr.net` とも到達不可）、CDN依存のままでは
  受け入れ条件のブラウザ実機検証（Playwright＋同梱Chromium）自体が成立しない。
- canvas形式はパン・ズーム・SVGエッジ・LOD切替など**ユーティリティクラスの適用範囲外の
  スタイル制御**（動的なz-index体系・カスタムkeyframes・属性セレクタでの状態切替）が主体で、
  Tailwindの利点（ユーティリティの再利用）がほとんど効かない。

## 却下した案

- **TailwindCSS CDN方式の継続**: `reports/` 標準方式（`.claude/rules/docs-workflow.md`）と
  揃う利点はあるが、上記のとおり不具合の温床かつ検証不能になる。標準方式の適用範囲を
  「一覧・表形式HTML」と明確化することで整合を取った（`SKILL.md`「外部依存・スタイルについて」）。
- **Tailwindのローカル同梱（ビルド済みCSSの埋め込み）**: オフライン閲覧は満たすが、生成側が
  クラスを追加するたびにビルドが要り、「テンプレートをコピーしてデータ部だけ差し替える」
  運用と噛み合わない。
