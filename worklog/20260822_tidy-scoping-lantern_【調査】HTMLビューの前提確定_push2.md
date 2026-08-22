---
title: worklog 20260822 【調査】HTMLビューの前提確定
type: log
description: issue #54 フェーズ2（調査）の試行錯誤ログ。
tags: [worklog, issue-mr-flow, 調査]
keywords: [CDN, TailwindCSS, cleanup-task, index.jsonl, flow-id, assets, 命名規則, 敵対的レビュー]
---

# worklog: 【調査】HTMLビューの前提確定と参照箇所の洗い出し

対象: issue #54 のフェーズ2〈調査〉（2026-08-22）。
全体作業計画: `plans/tidy-scoping-lantern.md`
個別作業計画: `plans/【調査】HTMLビューの前提確定と参照箇所の洗い出し.md`
push回数: 2〜3

## 試したこと

- `curl` でCDN到達性を測った（`cdn.tailwindcss.com` / `cdn.jsdelivr.net` とも
  `CONNECT tunnel failed, response 403`）。
- `git log --all` で `reports/*.html` の履歴を探した（0件）。**その後、敵対的レビューの指摘で
  作業ツリーが浅いクローンであることに気づき**、`git rev-parse --is-shallow-repository`（`true`）と
  `git for-each-ref`（4本のみ）を採って探索範囲を明示した。
- `grep` を7パターン流し、パターンごとのヒット件数を採った。当初は `templates/` 1本だけで
  「全数」と称しようとしていた。
- `plans/__probe__.html` / `reports/__probe__.html` を置いて `cleanup-task.sh --dry-run` と
  `extract-frontmatter.sh plans` を実行した。後始末は `trap ... EXIT` で保証した。
- `git check-ignore -v .claude/skills/issue-mr-flow/assets/x.html` で `.gitignore` の当たり判定を確認した。

## うまくいったこと

- Q1の判断軸を「CDN到達性」から「既存DDRの根拠がテンプレート化後も成り立つか」へ差し替えたことで、
  `i0141-01` の限定（`reports/` はCDN方式のまま）と衝突しない論理になった。
- Q6・Q7を読むだけでなく実行で確かめられた。とくにQ7は `plans/index.jsonl` に probe が
  現れないことを直接確認できた。
- `.claude/skills/issue-mr-flow/SKILL.md` の flow-id 5-3 が、本issueの成果物のパスまで
  含めて予約している記述を持つことに気づけた（フェーズ3で暫定記述の解除が要る）。

## ダメだったこと

- **`git log --all` の0件を「squash mergeで残っていない」と決め打ちしかけた。** 浅いクローンでは
  そもそも見えない。0件の解釈は探索範囲とセットでしか書けない。
- **全体作業計画で DDR を `i0048-*` と書いた**（正しくは `i0028-01`）。ワイルドカードで書くと
  検証されないまま残る。`.claude/rules/markdown-frontmatter.md` が定める識別子の形で書くこと。
- **`grep` 1パターンで「全数を洗った」と書きかけた。** 対象が2種類（改名と方式）あるのに、
  片方しか拾えないパターンだった。

## 敵対的レビューで受けた指摘のうち、MRへ投稿しなかったもの（報告のみ）

`adversarial-review` スキルの選別基準（確度 medium × 重大度 minor は報告のみ）に従い、
次の4件はMRへ投稿せずここへ残す。**4件とも計画・レポートへ反映済み。**

1. **probeファイルの後始末が失敗経路で保証されていない**（side-effect / medium・minor）。
   → 個別調査計画「Q6・Q7の実行確認」で `trap ... EXIT` を使う形へ直し、実行後に
   `git status --porcelain` で残骸が無いことを確認する手順を足した。
2. **前提が「いつ・どこで合意したか」を持たない**（missing-record / medium・minor）。
   → 個別調査計画の冒頭へ「前提（合意状況）」節を新設し、flow-id 1-5 の人間合意が
   得られていないこと、スコープ外3項目の出所を明記した。
3. **成果物のHTML自身の外部依存方式が決まっていない**（self-contradiction / medium・minor）。
   → 個別調査計画「成果物」節へ、自己完結CSSで書く理由（この環境では表示検証ができない）と、
   Q1がCDN維持と結論した場合の扱いを書いた。レポート本文の「この調査自身の限界」にも
   逸脱である旨を明記した。
4. **Q7が机上確認のみ**（verification-blind-spot / medium・minor）。
   → Q6と同じく probe を置いた実行確認へ変更した。

## 次の一歩

- フェーズ3（flow-id 3-1）: 個別作業計画を作る。テンプレート2本の必須／任意セクションを
  `REVIEW-POINTS.md` とSKILL.md「計画と実施結果の分離」の表から起こす。

---
