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

## GitLab実機検証（flow-id 3-6の続き）

フェーズ2で使ったコンテナ（`gitlab/gitlab-ce:18.5.4-ce.0`）を `docker start gitlab` で再開した
（`Exited (137)` から約170秒で `healthy`）。テスト用MRは `root/issue45-verify` の `!3`。

### 手順（フェーズ2と変えた点）

フェーズ2はAPIを直接叩く形だったが、今回は `projects/:id/` を含む**実関数を通す**必要があるため、
**remoteだけを持つ作業ディレクトリ**を用意した。`glab` はremote URLからプロジェクトを解決する
ため、クローンは不要である（`glab repo clone` は `git_protocol: ssh` 設定のため失敗し、
HTTP＋トークンでのcloneも `HTTP Basic: Access denied` になった。remoteを設定するだけで
`projects/:id` が `1 root/issue45-verify` に解決することを確認した）。

```bash
mkdir gl-clone && cd gl-clone && git init -q .
git remote add origin http://localhost:8929/root/issue45-verify.git
export GITLAB_HOST=localhost:8929
```

`Provider.sh` のディスパッチは、このリポジトリのremoteがGitHubのため使えない。フェーズ2と同じく
`gitlab_*` 関数を直接呼ぶ形で検証した（`get_provider` がself-hostedのGitLab URLを判定できない
issue #45の制約は未解消）。

### 確認できたこと

- `gitlab_add_mr_inline_comments 3 <findings>` が `{"posted":3,"summarized":1}` を返した。
  新規行・削除行・コンテキスト行の3ケースすべてが投稿され、diffに無いファイルへの指摘だけが
  サマリ（通常コメント1件）へ回った。
- **`gitlab_format_discussion_notes` の修正が効いていること**を実機で確認した。
  `gitlab_get_mr_unresolved_comments 3` の出力が次のようになり、位置が出るようになった
  （修正前は `[unresolved threadId=...]` のみで、どのファイルの何行目か分からなかった）。

  ```
  [unresolved threadId=3d843a... sample.txt:2] root: **[blocker / 確度: high / new-line]** 追加行への指摘
  [unresolved threadId=14fb15... sample.txt:4] root: **[major / 確度: medium / deleted-line]** 削除行への指摘
  [unresolved threadId=62b3c7... sample.txt:9] root: **[minor / 確度: high / context-line]** コンテキスト行への指摘
  [unresolved threadId=0d55f8...] root: Claude Codeより: 敵対的レビュー（AIによる自動レビュー）の結果です。
  ```

- サマリ（通常コメント）の本文に、投稿できなかった指摘が件数付きで載ることを確認した。
- 投稿したdiscussionは**削除せず残している**（レビュー時に確認したいというユーザーの指示）。
  MR: http://localhost:8929/root/issue45-verify/-/merge_requests/3

### ダメだったこと・詰まったこと（GitLab検証）

- **1回目の実行が `{"posted":1,"summarized":3}` になった。原因はテストデータ側の誤り**で、
  実装の欠陥ではなかった。APIの応答は
  `400 Bad request - Note {:line_code=>["can't be blank", "must be a valid line code"]}`。
  GitLabは**行の種類ごとに指定すべきキーが決まっている**。

  | 指摘したい行 | 指定するキー |
  |---|---|
  | 追加行（`+`） | `new_line` のみ |
  | 削除行（`-`） | `old_line` のみ |
  | 変更のない行（コンテキスト行） | `new_line` と `old_line` の**両方** |

  1回目は「コンテキスト行に `new_line` だけ」「追加行に両方」を渡しており、どちらも弾かれた。
  `gitlab_build_discussion_body` は渡された値をそのまま position へ組むだけなので、
  **正しく指定する責任はfindingsを作る側（サブエージェント）にある**。
  `.claude/agents/adversarial-reviewer.md` にこの対応表が無かったため、**「行の種類ごとの指定」
  節を追記した**（この検証で見つかった実際の不足）。
- **`export MSYS_NO_PATHCONV=1` した状態では、ネイティブjqがMSYS形式のパス（`/tmp/...`・`/c/...`）を
  開けず、`Could not open file` になる。** docker操作のために
  `.claude/rules/shell-script-style.md` が推奨している設定だが、同じシェルでjqにファイルパスを
  渡す関数を呼ぶと壊れる。**docker用のexportは、jqを使う処理と同じシェルへ広げないこと。**
  今回は `MSYS_NO_PATHCONV` を外したシェルで関数を呼び直して解決した。
- 既知の制限として、出力の `path:line` は新旧どちらの行番号かを区別しない（削除行の `:4` と
  追加行の `:4` が同じ表記になる）。GitHub版も `.line` をそのまま出しており表記は揃っているため、
  今回は変更していない。

## GitHub実機検証（flow-id 3-6の続き）

ユーザーの承認を得て、このPR #80 に対して `add_mr_inline_comments 80 <findings>` を実行した
（**投稿したレビューは削除せず残している**）。5ケースを1回のレビューにまとめて投稿し、
`{"posted":3,"summarized":2}` を得た。

| ケース | 指定 | 結果 |
|---|---|---|
| 有効行を明示 | `Github.sh` `line=241`（hunkは212〜324） | `Github.sh:241` へインライン投稿 |
| **`line` 未指定（ファイル全体）** | `Gitlab.sh`（hunkは117〜125 / 131〜149 / 233〜315） | **`Gitlab.sh:117`**（有効行の最小値）へ投稿 |
| マルチバイトを含むパス | `plans/【設計】【実装】【テスト】〜.md` `line=10` | そのままの位置へ投稿 |
| 有効行の外 | `HANDOFF.md` `line=5`（有効行は14〜209） | サマリへ |
| diffに現れないファイル | `README.md` | サマリへ |

- **`line` 未指定のfindingが1行目ではなく有効行の最小値（117）へ寄ることを実機で確認した。**
  flow-id 2-9のレビューで「ファイル単位の指摘は1行目に書けばよい」と合意した方針を、
  「既存ファイルの部分変更では1行目がdiffに含まれない」という制約に合わせて
  **有効行集合の最小値**として実装しており、その挙動が意図どおりであることが確かめられた。
- 投稿したスレッドが `get_mr_unresolved_comments 80` に `unresolved` として現れ、
  `[review unresolved threadId=PRRT_... .claude/scripts/src/vcs/Gitlab.sh:117]` のように
  位置つきで取得できることも確認した（＝既存の `comments` サブコマンドが、そのまま
  敵対的レビューの指摘一覧としても機能する）。
- レビュー本文（サマリ）に、インラインにできなかった2件が理由つきで載ることを確認した。

### 検証前に直したこと（既存規約との不整合）

`gh`/`glab` CLIは人間のアカウントで認証されているため、投稿者名では誰が書いたか判別できない。
`issue-mr-flow/SKILL.md` の `reply` サブコマンド手順2は、この理由でAIの返信本文へ
`Claude Codeより:` の署名を必須としているが、**インラインコメントの本文には署名が入って
いなかった**（レビュー本文＝サマリには入っていた）。同じ理由がそのまま当てはまるため、
`github_build_review_payload` / `gitlab_build_discussion_body` の両方で、本文の先頭へ
`Claude Codeより（敵対的レビュー）:` を付けるようにした。単体テストも追随させている
（GitLabは1件ずつ独立したdiscussionになり、まとめ役のレビュー本文が存在しないため、
署名が無いと人間の指摘と区別できなかった）。

## 次にやること

- flow-id 3-7（commit・push）→ 3-8（人間のレビュー）。
- **GitHub・GitLabの実機検証はどちらも完了**。投稿したレビュー・discussionは、レビュー時に
  確認できるよう削除せず残している。GitLabコンテナはレビュー後に `docker stop gitlab` する。
- フェーズ4で `type: review-points` を `.claude/rules/markdown-frontmatter.md` のtype表へ追記する
  （`【AIアセット反映】`）。
- フェーズ4で、GitLab検証で分かった「行の種類ごとの指定」を
  `.claude/docs/spec/adversarial-review.md` へ残す。
