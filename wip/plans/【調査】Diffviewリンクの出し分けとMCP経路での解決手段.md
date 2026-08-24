---
title: 【調査】Diffviewリンクの出し分けとMCP経路での解決手段
type: plan
description: issue #205 の個別調査計画。URL形式の裏取り、MCP経路でのMR/PR URL解決3案の評価、既存機構との整合を調べる
tags: [plan, research, issue-mr-flow]
keywords: [Diffview, files, diffs, git ls-remote, refs/pull, wip/state, HANDOFF, 差分アンカー, get_mr_diff_since_url, フォールバック]
---

# 【調査】Diffviewリンクの出し分けとMCP経路での解決手段（issue #205 / flow-id 2-1）

- 全体作業計画: `wip/plans/diffview-link-switchover.md`
- PR: #206

## 前提（合意状況）

- 上位の計画: `wip/plans/diffview-link-switchover.md`（flow-id 1-4 で作成）。
- **上位の全体作業計画も、この個別調査計画も、人間の合意を経ていない。** `HANDOFF.md` の進捗表で
  flow-id 1-5（全体作業計画に合意する）・2-3〜2-4（個別計画のレビュー往復）はいずれも `[]` である。
- **その状態で調査へ進む判断の根拠**: 非対話セッション（Claude Code on the web のリモート実行環境、
  `gh`/`glab` CLI不在のMCP経路）であり、人間のレビュー往復が成立しないため。代わりに
  **敵対的レビュー**（`.claude/skills/adversarial-review/SKILL.md`）を計画時に1回実行して
  指摘へ対応する。
- **したがって、後から上位計画が人間のレビューで覆ると、この計画のQ1〜Q6の枠組みごと作り直しに
  なりうる。** これは受け入れたうえで進める。

## この計画で何を調べるか

実装（フェーズ3）に入る前に決めなければならない**未決事項**は次の2つである。

1. **Diffview URLの形式が推測でなく裏取りできるか。** DDR i0013-01 は「MR/PRのURL文字列へ
   suffixを推測で付け足す」案を一度却下している。同じ轍を踏まないための根拠が要る。
2. **MCP経路（`gh`/`glab` CLI不在）で、hookがMR/PR URLをどう解決するか。** hookはシェル
   プロセスでありMCPツールを呼べないため、ローカルで参照できる情報から導く必要がある。

上記に付随して、既存機構との整合（差分アンカー・`get_mr_diff_since_url`）も確認する。

## 調査項目（問いの形）

### Q1. GitHub `/pull/<n>/files` は「レビューコメントを付けられるビュー」か。URL形式の根拠は何か

- 根拠として何が使えるか（GitHub APIが返す `html_url` からの導出か、公式ドキュメントか、
  リポジトリ内の既存の実機確認済み記述か）。
- GitLab `/-/merge_requests/<n>/diffs` は `gitlab_get_diff_anchor_base_url` が既に採用済み。
  その採用時の根拠（issue #127 のGitLab CE 18.5.4 実機確認）が本issueへ流用できるか。
- **リポジトリ内の記述だけで答えが出ない場合の次の手段を、あらかじめ決めておく**（下記「調べ方」）。

### Q2. DDR i0013-01 が却下した案と、本issueがやろうとしていることの違いは何か

- 却下の理由が本issueにも当てはまるのか、当てはまらないならなぜか。
- **当てはまるなら本issueの前提そのものが崩れる**ため、最初に確認する（下記「停止条件」）。

### Q3. MCP経路でMR/PR URLを解決する3案のうち、どれが成立するか

| 案 | 検証すること |
|---|---|
| A. `git ls-remote origin 'refs/pull/*/head'` | (1) **この実行環境で実際に実行し**、PR #206 が引けるか。(2) 所要時間（ベースラインとの差）。(3) HEADのSHAと突き合わせられるか。(4) **push直後のrefの伝播遅延**（pushしてから何秒後に引けるか）。(5) **fork元PR**（`origin` にrefが無い場合）の挙動。(6) **同一SHAに複数PRのrefが一致した場合**の選び方。(7) **失敗経路**——ネットワーク不達・認証プロンプトでのブロック・タイムアウトの検知方法（`GIT_TERMINAL_PROMPT=0` の要否、タイムアウト設定の有無）と、失敗時の縮退先。(8) オフライン時の所要時間。(9) GitLabの `refs/merge-requests/*/head` に相当物があるか |
| B. `wip/state/` の状態ファイル | 書く契機をフローのどこへ置けるか。`wip/state/review-links/` と同じ形にできるか。書き忘れたときの縮退先。**古くなった値（PRがクローズされた等）をどう扱うか** |
| C. `HANDOFF.md` のヘッダ `- PR:` 行 | 表記の安定性（`update-handoff-progress.sh` の `set-header` が生成する形は決まっているか）。パースの堅牢性。**flow-id 5-5 のリセット後は値が消える**ことの影響 |

- 単独ではなく**チェーン（安い順に試す）**にする価値があるか。
- **hookはpushのたびに走る**ため、各案のコスト（外部プロセス起動・ネットワークI/O）を測る。
  ただし**計測環境の制約**（下記「調べ方」）を結果へ必ず添える。
- **A案は「失敗しても縮退できるか」を採否の第一基準にする。** コストは第二基準とする
  （計測値をhook実機環境へ持ち込めないため。同上）。

### Q4. `get_mr_diff_since_url`（前回push〜今回pushの差分）もDiffviewへ寄せるべきか

- **GitHub**: PR `/files` に「特定のSHA範囲だけを見る」口があるか。
- **GitLab**: `?start_sha=` が使える。`gitlab_get_diff_anchor_base_url` が既に
  `<mrUrl>/diffs?start_sha=<sha>` を組み立てているため、範囲指定の口が実在することは
  リポジトリ内で確認できる。ただし `gitlab_mr_has_version_head` による前提
  （**MRバージョンのheadでないSHAを渡すとGitLabはエラーにせず無言で0ファイルを返す**）まで
  含めて評価対象にする。
- **プロバイダ間で結論が割れた場合の扱いを決める。** 「GitHubだけCompareのまま、GitLabだけ
  Diffview」は、2つのリンクの意味がプロバイダ間で食い違う状態になる。

### Q5. 差分アンカーの土台（`get_diff_anchor_base_url`）と二重にならないか

- `diff_url` がDiffviewになると、`anchor_compare_url` に渡る値も変わる
  （`post-push-compact-prompt.sh` が `anchor_compare_url="$diff_url"` と代入しているため）。
- **GitHub**: アンカー `#diff-<sha256>` は issue #42 で**Compareページ上でのみ**実機確認されて
  いる。**PRの `/files` ページでも機能するかは未確認**。機能しないならアンカーが壊れる
  ——**これは後退である**（下記「停止条件」）。
- **GitLab**: `gitlab_get_diff_anchor_base_url` は**常に `<mrUrl>/diffs` を返すわけではない**。
  実装は3分岐である。

  | 分岐 | 条件 | 戻り値 |
  |---|---|---|
  | (a) | `mr_url` が空（MCP経路等） | `compare_url` をそのまま |
  | (b) | `since_sha`・`mr_number` があり `gitlab_mr_has_version_head` が真 | `<mrUrl>/diffs?start_sha=<sha>` |
  | (c) | それ以外 | `<mrUrl>/diffs` |

  さらに**この関数は純粋関数ではなく `glab api` を呼ぶ**（`gitlab_mr_has_version_head`）。
- したがって調査項目は「同じ値になるか」ではなく次の2つである。
  1. 2回目以降のpush（`since_sha` あり）で土台が `?start_sha=` 付きになり、`diff_url` と
     一致しないケースをどう扱うか。
  2. **本issueがMCP経路で `mr_url` を解決できるようにすると、これまで分岐(a)で早期returnして
     いたMCP経路が、新たに `glab api` を呼ぶ経路（(b)の判定）へ入る。** この経路変化が
     許容できるか（CLI不在なら失敗して(c)へ縮退するはずだが、確認する）。

### Q6. 影響を受ける既存のテスト・spec記述はどれか

- `test_vcs_provider.sh` の該当アサーション（`*_get_mr_diff_url` / `*_get_mr_diff_since_url`）。
- `.claude/docs/spec/issue-mr-workflow.md` の次の4箇所。
  1. 「提供関数」表の `get_mr_diff_url` / `get_mr_diff_since_url` / `get_diff_anchor_base_url` の行。
  2. レビュー依頼メッセージの節。
  3. **`## 未決定事項・懸念点` の「（issue #13）`get_mr_diff_url`/`get_mr_diff_since_url` の
     URL形式: GitHub側のみブラウザ未検証」**。この項目はCompare方式を前提に
     「PR個別のサブタブ形式より安定していると考えられる」と書いており、本issueがDiffviewへ
     寄せると内容が現状と食い違う。同節の差分アンカー関連の項目も併せて確認する。
  4. 過去issueごとのchangelog（**書き換えず、新規エントリの追記で対応する**）。
- `references/mcp-fallback.md` のhook縮退表。

## 調べ方

- **Q1・Q2・Q5・Q6は、リポジトリ内のドキュメントとコードを読んで答える。**
  ドキュメント探索は `doc-search`（frontmatterインデックス）を第一手段にする。
- **Q1でリポジトリ内から答えが出なかった場合の次の手段**: GitHub MCPツール
  （`mcp__github__pull_request_read` 等）が返す `html_url` の形式を実際に取得して確認する。
  **WebFetch・curlへはフォールバックしない**（DDR i0014-01, i0034-01）。それでも
  「レビューコメントを付けられるビューか」が確認できない場合は「不明」と記録し、
  下記「停止条件」に従う。
- **Q3の案Aは、この実行環境で実際にコマンドを実行して測る。** 机上で「できるはず」と書かない。
- **Q3の調べ方には、DDR i0044-01 の該当記述の確認を含める**（`get_mr_for_branch` が
  `refs/pull/*` / `refs/merge-requests/*` から番号だけは取れるが、ref名前空間自体が
  プロバイダ差分として残るという先行調査がある）。**そこで既に判明していることと、今回
  新たに測ることを切り分ける。**
- **計測環境の制約を結果へ必ず明記する。** この実行環境はLinux（Claude Code on the web）で
  あり、**hookの主たる実行環境はgit bash（Windows）である**。
  `.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」が定めるとおり、
  fork単価が桁で違うため**Linuxでの計測値をそのままgit bash実機の値として扱わない**。
  計測は**ベースライン（`git rev-parse` 等ネットワークを伴わないgit操作）との差**で示す。
- **Q4のうちGitHubのURL仕様は、確定的な根拠が得られなければ「不明」と記録する。**
  推測を結論として書かない。

## やらないこと（スコープ外）

- 実装そのもの（**判断は flow-id 3-1 へ送る**）。この計画では方針の材料を集めるだけで、
  コードは変更しない。
- GitLabの実機確認。この環境にGitLabが無く、GitLab CE への実機確認は issue #127 の記録を
  参照するに留める（**新たな実機確認が必要と分かった場合は、その事実を結果へ書き、判断を
  flow-id 3-1 へ送る**）。
- ブラウザでの目視確認。この環境にブラウザが無いため、**「実際にコメントが付けられるか」は
  目視では確認できない**。この制約自体を結果へ明記する。

## 検証（この調査が完了したと言える条件）

```bash
# Q3-A: PR refが引けるか・HEADと一致するか
git ls-remote origin 'refs/pull/*/head' | grep "$(git rev-parse HEAD)"

# Q3-A: コスト（ベースラインとの差で見る。Linux環境の値であることを結果へ明記する）
for i in 1 2 3; do
  s=$(date +%s%3N); git ls-remote origin 'refs/pull/*/head' >/dev/null 2>&1; e=$(date +%s%3N)
  echo "ls-remote: $((e-s))ms"
done
for i in 1 2 3; do
  s=$(date +%s%3N); git rev-parse HEAD >/dev/null 2>&1; e=$(date +%s%3N)
  echo "baseline : $((e-s))ms"
done

# Q3-A: 失敗経路（認証プロンプトでブロックしないこと）
GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/does-not-exist/nope 2>&1; echo "rc=$?"

# Q6: 影響箇所の洗い出し
grep -rn 'get_mr_diff_url\|get_mr_diff_since_url' --include='*.sh' --include='*.md' \
  .claude | grep -v '^\.gemini/'
```

合格条件:

- Q1〜Q6のすべてに、**根拠付きの答えか「不明」のいずれか**が書かれていること。
- **Q3について、採用する案（またはチェーン）が1つに決まっているか、または
  「いずれも採らず現行のCompareページのままとする」という結論とその根拠が書かれていること。**
  上位計画の方針3（後退させない／解決できなければCompareのまま）に照らし、
  **「どの案も採らない」は正当な結論である**。完了条件を満たすために無理に1案を採用しない。
- 結果が `wip/reports/20260824_diffview-link-switchover_調査結果.md` と同名の `.html` に
  記録されていること。

### 停止条件（フェーズ3へ進んではいけない場合）

**上の合格条件は「全問が『不明』でも満たせる」形になっているため、次の停止条件を併せて置く。**

| 条件 | 対処 |
|---|---|
| **Q1が「不明」で終わった**（GitHubのDiffview URL形式を裏取りできなかった） | フェーズ3へ進まず、issueへ差し戻して人間の判断を仰ぐ。DDR i0013-01 が却下した「推測でのsuffix付け足し」をそのまま繰り返すことになるため |
| **Q2で、DDR i0013-01 の却下理由が本issueにも当てはまると判明した** | 同上。本issueの前提そのものが崩れる |
| **Q5でGitHubのアンカーが `/files` 上で機能しないと判明した**（または確認できなかった） | `diff_url` の切り替えとアンカーの土台を**分離する**（土台は検証済みのCompareのまま残す）か、GitHubを切り替え対象から外す。**いずれにせよ、その判断を結果へ明記する** |
| **Q3でどの案も成立しない** | 停止しない。「Compareのまま」という結論で実装フェーズへ進んでよい（issueの受け入れ条件が許容している） |
