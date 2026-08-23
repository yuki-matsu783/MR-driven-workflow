---
title: 【調査】SKILL.mdの分割単位と参照追従の実測
type: plan
description: issue-mr-flow/SKILL.mdをreferences/へ分割するにあたり、節構成・参照元・hook拡張可否・配布経路を実測するための個別調査計画
tags: [issue-mr-flow, skill, plan, research]
keywords: [節構成, 相互参照, 参照元分類, SessionStart hook, flow-id, sync-assets, describe抽出, 分割単位, 死荷重]
---

# 【調査】SKILL.mdの分割単位と参照追従の実測

## 前提（合意状況）

- 上位の計画: `plans/split-issue-mr-flow-skill-into-references.md`（全体作業計画。flow-id 1-4 で作成）
- 本計画は、その「フェーズ2〈調査〉」節に挙げたA〜Eを実施するための詳細計画である。
- **本セッションは非対話的な進行である。** flow-id 2-3/2-4 の人間レビューは
  `adversarial-review` スキルによる自動レビュー1回で代替する（全体作業計画「進め方（レビューの
  扱い）」）。上位の全体作業計画への合意（flow-id 1-5）も同じ扱いで、進捗記号は `[]` のまま残す。

## この計画で何をするか

`.claude/skills/issue-mr-flow/SKILL.md` を `references/` へ分割する設計を確定させるために、
**机上で決められない5点を実測する**。この計画は「これから何を調べるか」だけを書き、結果は
`reports/20260823_split-issue-mr-flow-skill-into-references_調査.md` へ書く。

## 変更対象

この計画は**調査**であり、リポジトリ内のGit管理下のファイルは変更しない。読む対象・実行する
対象・新規に作る成果物は次のとおり。

| ファイル | 操作 | 何をするか |
|---|---|---|
| `.claude/skills/issue-mr-flow/SKILL.md` | 読む | 節構成・相互参照の実測（A） |
| `SKILL.md` を参照している全ファイル | 読む | 参照元の全量分類（B） |
| `.claude/hooks/session-start.sh` ・ `HANDOFF.md` ・ `update-handoff-progress.sh` ・ DDR `i0113-01` | 読む | 現在地flow-idを機械的に得られるかの確認（C） |
| `test_install_to_project.sh` ・ `sync-assets.sh` ・ `install-to-project.sh` | 読む・実行 | 壊れるテストと配布経路の実測（D） |
| `.claude/skills/apply-mr-workflow-to-project/assets/` | **再生成される（副作用）** | `sync-assets.sh` が `rm -rf` して作り直す。`.gitignore` 対象のためコミット差分には出ないが、実行前に把握しておく |
| `reports/20260823_split-issue-mr-flow-skill-into-references_調査.md` と同名の `.html` | **新規** | 調査結果（正文はmd） |

## 調べる問い

### A. 節構成と相互参照

| 問い | 確かめ方 |
|---|---|
| A-1. H2/H3ごとの行範囲・バイト数はいくつか | 見出し行の行番号から範囲を算出し、`sed -n 'A,Bp' \| wc -c` |
| A-2. 節から節への参照（`下記「〜」` `上記「〜」` `[〜](#anchor)`）は何件・どの向きか | `grep -n` で `下記「` `上記「` `](#` を抽出し、参照元の節と参照先の節の対応表を作る |
| A-3. 「いつ読むか」で切ったとき、**ファイルをまたぐ**参照が何件生じるか | A-2の対応表へ分割案を当てて数える |

**A-3が本調査の核心である。** ファイルをまたぐ参照が多い切り方は、参照先を開くために結局
2ファイル目を読むことになり、死荷重が減らない。

### B. 参照元の全量分類

| 問い | 確かめ方 |
|---|---|
| B-1. `issue-mr-flow/SKILL.md` を参照しているのは何ファイル・何箇所か | `grep -rn --include='*.md' --include='*.sh'`（`index.jsonl` と `plans/` `worklog/` `reports/` を除く）。**行単位のgrepだけでは足りない**（下記） |
| B-1b. **行をまたいで折り返した参照**を何件取りこぼしているか | このリポジトリは約100桁で改行する慣習があり、`issue-mr-flow/` で行が終わり次行が `SKILL.md` で始まる参照が実在する（実例: `.claude/hooks/post-push-compact-prompt.sh:53-54`）。改行を空白へ正規化した写しに対して照合し直し、**行末が `skills/issue-mr-flow/` で終わる行の件数も別途出して** B-1 へ合算する |
| B-2. うち**節名を伴う**参照（`SKILL.md「〜」`）は何箇所で、どの節を指しているか | `grep -o` で節名を抽出し、節ごとに集計する |
| B-3. 各参照は次のどれか — (a) DDR本文 / (b) specの過去changelog / (c) 現在の状態を説明する節 / (d) パスのみで節名を伴わない | 1件ずつファイルと文脈を見て分類する |

**(a)(b) は書き換えない**（`.claude/rules/docs-workflow.md`）。**(c) だけを更新対象にする。**
(d) はパスが変わらないので対応不要。

### C. SessionStart hook で「現在地flow-id」を得られるか

| 問い | 確かめ方 |
|---|---|
| C-0. **DDR i0113-01 が同じ材料（`HANDOFF.md` の進捗表）を却下した理由**が、現在地flow-idの解決でも当てはまるか | i0113-01 の却下理由は (1) リセット直後・ブランチ作成直後は空でフローの最初と最後を取りこぼす、(2) 表の書式変更に引きずられる、の2点。当てはまる場合の代替材料（ヘッダの `- 現在のループ:` 行・ブランチ上の作業ファイル）も比較対象に含める |
| C-1. `HANDOFF.md` の進捗表から「次に着手すべきflow-id」を機械的に決められるか | 進捗記号の規約（`[x]` `[-]` `[]`）を `update-handoff-progress.sh` と `.claude/docs/spec/update-handoff-progress.md` で確認する。**「最初の `[]` 行を採る」方式は本ブランチで既に破綻している**（1-5 が `[]` のまま 1-6 が `[x]`）ため、複数の候補方式を実データに対して試す |
| C-2. 次の縮退ケースでどう振る舞うか — (i) `cleanup-task.sh` 直後で**進捗表そのものが無い**、(ii) **全行が `[]`**（着手直後）、(iii) **穴あき**（先行flow-idが `[]` のまま後続が `[x]`。非対話セッションとループ範囲では**これが既定**）、(iv) 表の書式が想定と違う | 各ケースのHANDOFF.mdを作って実際に判定させる。判定できないときは**注入しない**（fail-open）を縮退先の既定にする |
| C-3. flow-id → 参照ファイルの対応をどこに持つか（hook内のテーブル / SKILL.md の表から抽出） | 二重管理の有無で比較する |
| C-4. 注入テキストのサイズ上限（`CONTEXT_SIZE_WARN_BYTES` 8000バイト）を圧迫しないか | 追加する行のバイト数を見積もる |
| C-5. `references/*.md` に frontmatter を付けるか、HTMLビューと同様に**対象外**とするか | `.claude/rules/markdown-frontmatter.md` の `type` 表と `extract-frontmatter.sh` の走査対象を確認する。**付けると決めるならtype表への追記はフェーズ3へ前倒す**（フェーズ4では、表に無い `type` を持つmarkdownが先にコミットされてしまう） |

**C-1が否なら**、受け入れ条件が許す代替（理由を記録し、読み直し指示文の対象範囲を分割後の
構成へ合わせる）へ倒す。その判断の根拠を残すことが調査の目的である。

### D. 壊れるテストと配布経路

| 問い | 確かめ方 |
|---|---|
| D-1. `test_install_to_project.sh` の `describe_headings()` は何を前提にしているか | 該当箇所を読み、`describe` 節を移したときに何が起きるかを実際に試す |
| D-2. `sync-assets.sh` はスキルディレクトリをどう配るか。`references/` は自動で渡るか | スクリプトを読み、`sync-assets.sh` → `install-to-project.sh` を実行して配布先にサブディレクトリが現れるかを**実測**する。**配布先は必ず `mktemp -d` で作った一時ディレクトリを引数で渡す**（`install-to-project.sh` は引数省略時に `DEST_DIR="."` となり、確認プロンプトなしにこのリポジトリ自身を上書きする）。配布先は git リポジトリである必要があるため `git init` しておく |
| D-3. 他に SKILL.md の**構造・節名**へ依存しているテスト・スクリプトはあるか | `grep -rn --include='*.sh' 'SKILL\.md' .` の**全件**を確認し、**ヒット件数を結果へ書く**。`grep PATTERN -- '*.sh'` は `--` 以降を検索対象パスとして扱うため `No such file or directory` で必ず0件になる（「異常が無ければ何も出ない検証」の典型）。既知の依存先: `test_install_to_project.sh:89`（`describe` 節をawk抽出）・`Provider.sh:357,373`（実行時メッセージが節名を名指し）・`test_vcs_provider.sh:284-285`（その文字列を完全一致比較） |

### E. 分割案の比較

| 問い | 確かめ方 |
|---|---|
| E-1. 「いつ読むか」で切った案は具体的に何ファイルになるか | issue本文の8区分を出発点に、A-3の結果で調整する |
| E-2. 各flow-idで「本文＋その時点で開く参照ファイル」の合計バイト数はいくつか | 分割案ごとに算出する |
| E-3. 「サイズだけで機械的に割る」案と比べて、どれだけ死荷重が減るか | E-2をフェーズ3の代表的な地点（flow-id 3-6）で比較する |

## やらないこと（スコープ外）

- **実際の分割作業**（ファイルの作成・SKILL.md の書き換え）。フェーズ3で行う。
- **hookの実装**。C の結果を受けてフェーズ3で行う。
- **文言の改善**。移動対象の節の中身は読むが、直さない（判断は別issueへ送る）。

## 検証（この調査が終わったと言える条件）

```bash
# A: 節ごとの行範囲（見出し行の行番号から範囲を出す）
grep -n '^#\{1,4\} ' .claude/skills/issue-mr-flow/SKILL.md | wc -l   # 見出しの総数を出す

# B-1: 参照元の全量（件数を必ず出す。0件なら0件と分かる形にする）
grep -rn --include='*.md' --include='*.sh' 'issue-mr-flow/SKILL\.md' . | grep -cv 'index.jsonl'
# B-1b: 行をまたいで折り返した参照（行末が skills/issue-mr-flow/ で終わる行）
grep -rn --include='*.md' --include='*.sh' 'skills/issue-mr-flow/$' . | wc -l

# D-3: SKILL.md の構造・節名へ依存するスクリプト（-- '*.sh' は使わない）
grep -rn --include='*.sh' 'SKILL\.md' . | wc -l

# D-2: 配布経路の実測（配布先は必ず一時ディレクトリを渡す）
dest="$(mktemp -d)" && git -C "$dest" init -q
bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh
bash .claude/skills/apply-mr-workflow-to-project/scripts/install-to-project.sh -f "$dest"
find "$dest/.claude/skills/issue-mr-flow/" -maxdepth 2
```

- 上記の各コマンドが**件数を出力**しており、0件のときに「実行していない」と区別できる。
- A〜E の各問いに、**実測値または実行結果を伴う**回答がある（推測で埋めた項目が無い）。
- B-3 の分類が**全件**に付いている（サンプリングで済ませない）。
- D-2 が「実際に配布先へ `references/` が現れた」というコマンド出力で裏付けられている。
- E-3 が数値の比較になっている。
- 結果が `reports/20260823_split-issue-mr-flow-skill-into-references_調査.md` と同名の `.html` に
  書かれている。
