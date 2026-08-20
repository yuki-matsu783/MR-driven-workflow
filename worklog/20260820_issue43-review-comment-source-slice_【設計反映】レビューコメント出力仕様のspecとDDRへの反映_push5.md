---
title: worklog 20260820 issue43 設計反映・AIアセット反映（push5）
type: log
description: issue #43 の反映フェーズ（spec/DDR/スキル/ルール）の試行錯誤ログ
tags: [worklog, docs, spec, ddr]
keywords: [spec, DDR, changelog, SKILL, rules, 反映]
---

# worklog: 【設計反映】【AIアセット反映】

対象: issue #43 レビューコメント取得の出力仕様見直し（2026-08-20）。
全体作業計画: `plans/issue43-review-comment-source-slice.md`
個別反映計画: `plans/【設計反映】レビューコメント出力仕様のspecとDDRへの反映.md` /
`plans/【AIアセット反映】ソーススライス化に伴うスキル・ルールの改訂.md`
push回数: 5

## 試したこと

- 反映対象を `grep -n "diffを含む\|該当diff\|diffHunk\|gitlab_format_discussion_notes"` で
  洗い出した（spec 2ファイル・SKILL.md・rules）。9箇所が該当。

## うまくいったこと

- **9箇所のうち5箇所は過去changelog（`## 影響範囲` 配下の issue #48 / #42 / #77 の節）だと
  判別できた。** `.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は
  changelogを対象に含めない」と同じ理由で、**書き換えてはいけない**。機械的な一括置換をせず
  行番号で仕分けたことで、当時の記録を壊さずに済んだ。

- 新節「レビューコメントのソーススライス」を `### レビューコメントへの返信` の直後
  （`### チャットで受けたレビュー判断の記録` の直前）へ入れた。前節が箇条書きで終わっており、
  節全体にかかる地の文が末尾に無いため、間に挟んでも係り先が変わらない
  （`.claude/rules/docs-workflow.md`「既存ドキュメントへ新しい見出しを差し込むとき」）。
  挿入後に前後3行を目視し、空行が2つ続いていないこと・次の見出しの直前に空行が1つあることを
  確認した。changelogエントリも同様に `## 設定項目` の直前へ入れて確認した。
- DDR 0059 のリンク先を機械的に検査した（`re.findall(r'\]\(([^)]+)\)')` → `os.path.exists`）。
- `bash .claude/scripts/src/extract-frontmatter.sh .` → `files=108 built=15 failed=0`。
- `bash .claude/scripts/src/search-frontmatter.sh --type ddr --text 断面` で 0059 が引けた。

## ダメだったこと

- **DDR 0027 のファイル名を記憶で書いて外した。** `0027-gh_glab-CLI不在時はGitHub公式MCP
  サーバーで代替しWebFetchへは戻らない.md` と書いたが、実際は
  `0027-gh_glab-CLI不在時はMCPフォールバック経路へ機構的に誘導する.md` だった。
  リンク先の存在チェックを機械的に回して気づいた。**DDRへの相互リンクを書いたら必ず
  `os.path.exists` 相当で検査する**こと（`ls .claude/docs/ddr/ | grep '^00NN'` でもよい）。

- AIアセット反映で `.claude/rules/shell-script-style.md` へ制御文字の注記を足す際、**その注記の
  例文自体に生の0x1Fを書いてしまい**、`python` の `str.replace` が空文字列を探して空振りした
  （`assert '\x1f' not in s` で検知）。注記が警告している失敗を、注記を書く操作で再現した形。
  最終的に `s.replace('\x1f', '\\u001f')` で直した。**この種の混入は目視では絶対に見つからない**。

## 次の一歩

- flow-id 4-10（MR description更新）→ フェーズ5（5-1 コンフリクト検知 → 5-2 関連issue通知 →
  5-3 片付け → 5-4 Draft解除）へ進む。
