---
title: worklog 20260819 【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント push7
type: log
description: issue #77 フェーズ3の作業ログ（push7）。flow-id 3-5（MR description更新）とflow-id 3-6（成果物1〜7の実装）の記録。
tags: [worklog, issue-mr-flow, implementation]
keywords: [worklog, issue77, Github.sh, Gitlab.sh, Provider.sh, 有効行, position, adversarial-review-count, collect-review-points, REVIEW-POINTS]
---

# worklog: 【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント

対象: issue #77 MRへの敵対的レビューを行うスキル・専任サブエージェントを追加する（2026-08-19）。
全体作業計画: `plans/prancy-herding-kahan.md`
個別作業計画: `plans/【設計】【実装】【テスト】敵対的レビュースキルと専任サブエージェント.md`
push回数: 7

## 試したこと

- flow-id 3-5: 作業計画の内容でMR descriptionを更新した（`set_mr_description 80`）。
- flow-id 3-6: 成果物1〜7をすべて実装した。1〜4（純粋関数・スクリプト・観点表の実体）を先に
  完成させ、テストが通ってから 5〜7（エージェント・スキル）へ進んだ。

## うまくいったこと

- **成果物1（`Github.sh`）**: `github_valid_ranges_from_files_json` /
  `github_filter_findings_by_valid_lines` / `github_build_review_payload` の3つの純粋関数と、
  投稿本体 `github_add_mr_inline_comments`。
- **成果物2（`Gitlab.sh`）**: `gitlab_build_discussion_body` / `gitlab_add_mr_inline_comments`。
  あわせて `gitlab_format_discussion_notes` に `position` の出力を追加した
  （新規行は `new_path:new_line`、削除行は `old_path:old_line`）。
- **成果物3（`Provider.sh` ほか）**: `add_mr_inline_comments` のディスパッチ、
  プロバイダ非依存の `format_findings_summary`、`mcp_tool_hint` のケース追加、
  `issue-mr-flow/SKILL.md` のMCP対応表への行追加、`adversarial-review-count.sh`。
- **成果物4**: `REVIEW-POINTS.md` ×4（ルート・`.claude/`・`plans/`・`reports/`）、
  `collect-review-points.sh`、`.claude/skills/review-points/SKILL.md`。
- **成果物5〜7**: `.claude/agents/adversarial-reviewer.md`、
  `.claude/skills/adversarial-review/SKILL.md`、`issue-mr-flow/SKILL.md` への
  「敵対的レビューの位置づけ」節の追加。
- テストは3本すべて緑（`test_vcs_provider.sh` 85件 / `test_adversarial_review_count.sh` 22件 /
  `test_collect_review_points.sh` 17件）。
- **PR #80の実データで有効行の算出を確認した**（投稿はしていない）。`HANDOFF.md` の有効行が
  `[[14,172]]` と算出され、`line=5` の指摘がサマリへ回った。フェーズ2の実機確認（当時は14〜107、
  `line=5` が422）と整合する。diffに現れないパスもサマリへ回った。
- **縮退の確認**: `PATH` から `gh` を外すと `get_vcs_access_mode` が `mcp` を返し、
  `add_mr_inline_comments` が代替MCPツール名を提示して終了コード1で失敗した。

## 計画から変えたこと（レビューで確認してほしい点）

1. **`github_valid_lines_from_patch`（patch文字列から有効行を列挙）を、
   `github_valid_ranges_from_files_json`（`pulls/<n>/files` のJSONから範囲を返す）へ変えた。**
   - 理由1: 有効行を**1行ずつ列挙**すると、大きな差分でjqへ渡すデータ量が差分の大きさに比例して
     増える。`--argjson` / `--slurpfile` へ渡すデータは可変・無制限にしない
     （`.claude/rules/shell-script-style.md`「大きなJSONを--argjson等でjqへ渡さない」）。
     範囲 `[[14,172]]` で持てば、hunk数にしか比例しない。
   - 理由2: ファイルごとにpatchを取り出して関数を呼ぶと、**ファイル数に比例して外部コマンドを
     起動する**ことになる。files JSON全体を1回のjqで処理すれば起動は1回で済む。
2. **確度・重大度による投稿／報告の振り分けを、シェル関数ではなくスキルの手順（手順7）として
   書いた。** 全体作業計画では `filter_findings_for_posting` という関数案があったが、個別作業計画の
   関数一覧には入っていなかった。振り分けは「この指摘を人間に見せる価値があるか」という判断で
   あり、機械的な条件分岐に落とすと、確度の自己申告を額面どおり信じることになる。**技術的に
   投稿可能かどうか**（有効行の検証）だけを関数側に持たせ、**投稿すべきかどうか**はスキル側に
   置いた。上限10件の絞り込みも同じ理由でスキル側にある。

## ダメだったこと・詰まったこと

- **jqの正規表現に書いたバックスラッシュが、ツール経由でファイルへ書き出す途中で1つに潰れた。**
  `capture("\\+(?<s>...")` と書いたつもりが `capture("\+...")` になり、jqが
  `Invalid escape at line 1, column 4` で落ちた。**文字クラス `[+]` に書き換えて回避した**
  （バックスラッシュを使わない書き方にするのが確実）。
  - さらに、これを `perl -0pi -e 's/.../.../'` で直そうとしたところ、**perlのパターン中の
    バックスラッシュも同じように潰れ**、`[+]+` という別の壊れ方をした。
    エスケープを含む修正は、置換コマンドで書かずヒアドキュメント経由で行うのが安全。
- **`printf '...\n'` を含む行を `sed` の置換文字列として差し込んだら、`\n` が実際の改行へ展開され、
  1行が2行に割れた**（`.claude/rules/shell-script-style.md`「`awk`/`sed`の置換文字列で `\r` を
  含むシェルコードを生成しない」と同じ現象が `\n` でも起きた）。
  ヒアドキュメントで1行だけのファイルを作り、`sed -n` で分割した前後と連結し直して修正した。
- **150行規模のヒアドキュメントをBashツールへ渡したところ、`unexpected EOF while looking for
  matching '` でパースに失敗した。** クォート付きヒアドキュメント（`<<'EOF'`）なので本来は
  中身のクォートを解釈しないはずで、原因は特定できていない。
  **長いスクリプトの生成はWriteツールで行い、差し込みだけをBashで行う**形に切り替えて解決した。
- push6の教訓（差し込み前に `sed -n` で端点を確認する）は今回守れており、差し込みのずれは
  発生しなかった。

## 次にやること

- flow-id 3-7（commit・push）→ 3-8（人間のレビュー）。
- **GitHub実機での投稿確認（`add_mr_inline_comments` のend-to-end）は未実施。**
  提出済みレビューは削除できず、レビュー中のPR #80へbotのレビューが増えるため、
  実行の可否をユーザーへ確認してから行う。
- フェーズ4で `type: review-points` を `.claude/rules/markdown-frontmatter.md` のtype表へ追記する
  （`【AIアセット反映】`）。
