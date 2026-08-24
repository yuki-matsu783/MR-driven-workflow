---
title: i0168-02. 表紙スライドの型名はtitleでなくcoverにする
type: ddr
description: スライド型8種のうち表紙の型名を、調査素案のtitleからcoverへ改めた意思決定（フィールド名titleとの衝突回避と3箇所同一使用の契約）
tags: [ddr, slides, schema, naming]
keywords: [html-slides, cover, title, 型名, enum, data-type, スキーマ, 契約, issue168]
---

# i0168-02. 表紙スライドの型名はtitleでなくcoverにする

## 背景

html-slidesスキル（issue #168）のスライド型8種は、テンプレートの `data-type` 属性・
スキーマの `type` enum・サブエージェント2本の受け渡し契約の**3箇所で同一の文字列**として
使われる（1箇所でも食い違うと `slide-html-generator` が構成案を常に差し戻す）。フェーズ2調査の
素案（Q5）は表紙の型名を `title` としていた。

## 決定

**表紙の型名は `cover` とする**（8種: `cover` / `section` / `bullets` / `two-column` /
`diagram` / `table` / `comparison` / `summary`）。

- cover の表示文言は既定で `meta`（発表タイトル等）から採り、型固有の `title`/`subtitle` は
  任意（省略時は meta の値）。

## 理由

- スキーマでは表紙以外のほぼ全型が**必須フィールド `title`（スライド見出し）**を持つ。
  型名も `title` にすると、`type: "title"` と `title: "..."` が同じJSONオブジェクト内で
  別の意味の同名語として並び、構成案の読み書き・エージェントへの指示・レビューのすべてで
  取り違えの温床になる。
- 型名は「そのスライドが何であるか」を表す語彙であり、`cover` は .pptx 側のレイアウト語彙
  （タイトルスライド／表紙）への対応付けでも曖昧にならない。

## 却下案

| 案 | 却下理由 |
|---|---|
| 調査素案どおり `title` | 上記のとおりフィールド名 `title` と衝突する。素案の時点ではフィールド構造が未確定で、衝突が見えていなかった |
| `title-slide` のような複合名 | 衝突は避けられるが、8種の中で1つだけ複合語になり対称性が崩れる。`cover` で十分に一意 |

## 補足

この変更は「調査結果を後段の文書へ転記する際に独自に変えない」原則の例外として、
**変更点と理由を明示して**フェーズ3計画のレビューで確定した（issue #168。原則の側は
`wip/plans/REVIEW-POINTS.md` の観点として追記済み）。
