---
title: ルール読込条件と前方一致の調査結果
type: report
description: issue #47のルール本文が依拠する事実（.claude/rules配下の自動読込条件、permissions前方一致の照合単位、hook誤検知の発火範囲、新規ファイルの是非）の実機調査結果
tags: [report, investigation, rule, issue-47]
keywords: [alwaysApply, 自動読込, permissions, deny, 前方一致, 部分コマンド, hook誤検知, description, 実機確認, issue-47]
---

# ルール読込条件と前方一致の調査結果

- issue: [#47](https://github.com/yuki-matsu783/MR-driven-workflow/issues/47)
- PR: [#132](https://github.com/yuki-matsu783/MR-driven-workflow/pull/132)
- 全体作業計画: `plans/prancy-prancing-dewdrop.md`
- 個別調査計画: `plans/【調査】ルール自動読込条件とコマンド文字列の前方一致.md`
- flow-id: 2-6
- 実施日: 2026-08-20
- **実行環境: Claude Code on the web（リモート実行環境、Linux）。** 本レポートの実測値はすべて
  この環境のものである。ユーザーの常用環境（Windows / git bash）での再現は未確認。

## 結論の要約

| # | 問い | 結論 | 確度 |
|---|---|---|---|
| 1 | `.claude/rules/` 配下の新規ファイルは自動で読み込まれるか | **既存6ファイルは `alwaysApply` の有無に関わらず全て読み込まれた。新規ファイルについては未確認**（フェーズ3で実測する） | 既存: 実測。新規: **未確認** |
| 2 | 1行目コメントで `permissions` の前方一致は外れるか | **外れない**（実測4ケース）。照合は「コマンドを部分コマンドへ分解し、各部分コマンドの先頭で照合する」形 | 実測 |
| 3 | hook誤検知はコメント本文でも起きるか | **起きる。** hookスクリプトはコマンド文字列**全体**を検査し、コメント行を除外しない | 実測＋コード |
| 4 | 新規ファイルにするか既存へ追記するか | **新規ファイル**（既存6ファイルのどのスコープにも収まらない） | 判断 |

**issue #47 の付帯制約が挙げる理由（前方一致が外れる）は、この環境では成り立たない。**
ただし結論（1行目にコメントを置かない）を変える必要があるかは別問題であり、「設計への反映」節で扱う。

## 調査1: `.claude/rules/` 配下の自動読込条件

### 確かめたこと

**読み込み対象を指定する設定は存在しない。**

```bash
jq -r 'paths(scalars) as $p | "\($p|join(".")) = \(getpath($p))"' .claude/settings.json
```

出力に現れたキーは `permissions.*` / `plansDirectory` / `autoCompactWindow` / `hooks.*` のみで、
ルールの読み込み対象を指すキーは1つも無い。

**`@import` 経路も存在しない。**

```bash
grep -rn '^@' AGENTS.md CLAUDE.md GEMINI.md
# → CLAUDE.md:11 と GEMINI.md:11 の2行のみ（どちらも @./AGENTS.md）
```

`AGENTS.md` は `.claude/rules/` を**文章で参照している**だけで `@import` していない。したがって
`CLAUDE.md` → `AGENTS.md` の連鎖をたどっても `.claude/rules/*.md` には到達しない。

**SessionStart hookも注入していない。**

```bash
grep -rc 'rules' .claude/hooks/ | grep -v ':0$'
# → post-push-usage-report.sh:1 / post-push-compact-prompt.sh:1 /
#    lib/UsageTracking.sh:5 / post-issue-create-notice.sh:2
#    （session-start.sh は一覧に現れない＝0件）
```

`.claude/hooks/session-start.sh` は `rules` という語を1度も含まない。**この確認は0件が期待値だが、
0件だけでは「参照が無い」と「パターンが誤っている」を区別できないため、`.claude/hooks/` 全体での
件数を対にして出し、`grep` 自体が機能していることを示している。**

**`alwaysApply` は読み込みの条件ではない。**

| ファイル | `alwaysApply: true` | 本セッションで読み込まれたか |
|---|---|---|
| `directory-structure.md` | あり | された |
| `docs-workflow.md` | あり | された |
| `git-workflow.md` | あり | された |
| `markdown-frontmatter.md` | **なし** | **された** |
| `powershell-encoding.md` | **なし** | **された** |
| `shell-script-style.md` | **なし** | **された** |

6ファイル中3ファイルは `alwaysApply` を持たないのに読み込まれている。設定にも `@import` にも
hookにも経路が無いことと合わせると、**Claude Code本体が `.claude/rules/*.md` をディレクトリ単位で
プロジェクト指示として読み込んでいる**と考えるのが最も素直である。実際、開始時コンテキストでは
各ファイルが `Contents of <path> (project instructions, checked into the codebase)` という
見出しで提示されていた。

### 確かめられなかったこと

**新規ファイルが読み込まれるかは、まだ確かめていない。** 上の観測は**既存**6ファイルについての
ものであり、「既存ファイルが他所から名指しで参照されている可能性」を完全には排除できない
（経路を3つ潰したので可能性は低いが、証拠としては別物である）。

**受け入れ条件1が求めているのは「今回追加するルールが読み込まれることを確認できている」ことで
あるため、この差は埋めなければならない。** フェーズ3でルールファイルを作った後、新しいセッションで
当該ファイルがコンテキストへ入るかを実測する（本セッションでは自分の開始時コンテキストを
作り直せないため、ユーザーへ確認を依頼する）。

**他の実行経路は未確認。** このリポジトリは Claude Code（ローカルのgit bash）・
Claude Code on the web・Gemini CLI の3経路を想定している。`GEMINI.md` が `@import` するのも
`./AGENTS.md` だけで、`.gemini/rules` は `.claude/rules` へのローカルリンクである。
**Gemini CLIが `.gemini/rules/*.md` を自動で読むかは本調査の範囲外。**

## 調査2: `permissions` の照合単位

### 確かめたこと（実測）

`.claude/settings.local.json` へ**無害なパターン**を一時的に置いて実測した。

```json
{ "permissions": { "deny": ["Bash(echo arv-probe*)"] } }
```

**この設定はセッション途中でも即座に反映された**（再起動不要。個別調査計画が挙げていた
「効かないかもしれない」という限界は、この環境では顕在化しなかった）。実験後、このファイルは
削除済みで、コミットしていない。

| # | Bashツールへ渡したコマンド | 結果 |
|---|---|---|
| A | `echo arv-probe-case-a`（1行） | **拒否された** |
| B | 1行目コメント ／ 2行目 `echo arv-probe-case-b` | **拒否された** |
| C | 1行目 `set -euo pipefail` ／ 2行目コメント ／ 3行目 `ls /tmp >/dev/null` ／ 4行目 `echo arv-probe-case-c` | **拒否された** |
| D | `printf '%s\n' "echo arv-probe-case-d は引数の中の文字列"` | **実行された** |

拒否時のメッセージは
`Permission to use Bash with command <コマンド全文> has been denied.` である。

### 導かれるモデル

- **B・Cから**: 先頭にコメント行があっても、対象コマンドが何行目にあっても、`deny` は効く。
  **「コマンド文字列全体の先頭で前方一致する」というモデルではない。**
- **Dから**: 対象語が引数の中の文字列にすぎない場合は効かない。
  **「コマンド文字列全体に対する部分一致」というモデルでもない。**
- 4ケースすべてを説明するのは「**コマンドを部分コマンドへ分解し、各部分コマンドの先頭で
  照合する**」というモデルである。

### 参考: hookの `if` フィールドも同じ挙動だった

`permissions` とは別物だが、同じ `Bash(...)` 書式を使う `hooks[].if` についても実測した
（**この観測を `permissions` の根拠には使っていない**。敵対的レビューの指摘に従い、両者は
別物として扱う）。

| # | コマンドの構成 | push検知hookの発火 |
|---|---|---|
| 1 | 1行目 `set -euo pipefail` ／ 2行目 対象コマンド | した |
| 2 | 1行目 `set -euo pipefail` ／ 2行目コメント ／ 3行目 `echo` の引数に対象語 | しない |
| 3 | 1行目コメント ／ 2行目 対象コマンド | した |

`permissions` と同じモデルで説明できる。

### リポジトリの既存記述との食い違い

`.claude/rules/git-workflow.md`「push検知hookの誤検知」と
`.claude/docs/spec/issue-mr-workflow.md`「制約」、および
`.claude/docs/ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md`
「副次的な確認事項」は、issue #23 の実機観測3回をもとに **`if` は前方一致ではなく部分一致** と
記録している。具体的には「heredocで渡すissue本文・MR descriptionの**地の文**に該当語が含まれる
だけのケースで発火した」とある。

**上表の#2は、その記述であれば発火するはずだが、発火しなかった。** 一方で
「`cd /c/Users/... && ...` のようにコマンドが該当語で始まっていないケース」で発火したという
観測は、部分コマンド分解モデルでも説明できる（`&&` の右辺が対象コマンドになるため）。

つまり食い違うのは**「地の文で発火する」という一点**である。原因の候補は次の2つで、本調査では
切り分けられなかった。

1. Claude Codeのバージョン差（issue #23 は本調査より前の時点）。
2. プラットフォーム差（issue #23 は Windows / git bash、本調査は Linux のリモート実行環境）。

**なお、issue #23 の観測が「地の文でブロックされた」という体験だったのであれば、それは `if` では
なく `block-direct-git-commit.sh`（調査3）の挙動だった可能性がある**（下記）。ただしDDR 0022 が
言及しているのは push 側の集計・カーソル前進であり、そちらは `if` を経由するため、この説明では
すべては説明できない。

## 調査3: hook誤検知がコメント本文で発火する範囲

### 確かめたこと

**hookスクリプト本体は、コマンド文字列の全体を検査し、コメント行を除外しない。**

```bash
grep -n "grep -qiE" .claude/hooks/*.sh
# block-direct-git-commit.sh:50   : コミット操作の検出
# post-push-compact-prompt.sh:231 : push の検出
# post-push-usage-report.sh:331   : push の検出
```

いずれも `printf '%s' "$command" | grep -qiE '<2語を空白区切りで並べた正規表現>'` の形で、
`$command` は `tool_input.command` **全体**である。コメント行を除外する処理は存在しない
（`grep -c` で0件）。

**本セッションで実際に踏んだ。** flow-id 1-6 で、HANDOFF.md の地の文へ `deny` のパターン文字列を
そのまま書いてBashツールへ渡したところ、`block-direct-git-commit.sh` が exit 2 でブロックした。

### `if` との違いに注意する

**この2つは別の仕組みであり、混同すると根拠を取り違える。**

| | `hooks[].if` | hookスクリプト内部の `grep` |
|---|---|---|
| 誰が判定するか | Claude Code本体 | hookスクリプト自身 |
| 判定単位 | 部分コマンド（調査2の実測） | コマンド文字列**全体**の部分一致 |
| `block-direct-git-commit.sh` | **`if` を持たない**（matcherは `Bash\|PowerShell` のみ） | これだけで判定する |
| push検知の2つ | `if` を持つ | `if` を通過した後に再チェック |

つまり **`block-direct-git-commit.sh` は `if` を経由しないため、地の文の該当語で必ず発火する**。
一方 push 検知の2つは `if` で絞られるため、この環境では地の文だけでは発火しない。
**「コメント本文で誤検知する」という注意が最も強く当てはまるのは、コミット側である。**

### 既存ルールとの重複の切り分け

`.claude/rules/git-workflow.md` には既に次の2箇所がある。

| 箇所 | 内容 |
|---|---|
| 「コミット運用」節のAIエージェント向け注記 | コミットメッセージ・PR description・スクリプトのコメントで2語を連続させない |
| 「push検知hookの誤検知」節 | 同じ注意をpush側について。長文はファイル経由で渡す |

**新ルールが足すのは「コマンド内コメントを書くときの注意」という文脈だけである。** 誤検知の
仕組みそのものの説明は `git-workflow.md` にあるので繰り返さず、参照で済ませる
（`.claude/rules/docs-workflow.md` の「同じ内容を複数ファイルに重複して書かない」）。

## 調査4: 新規ファイルにするか既存へ追記するか

### 既存6ファイルのスコープ

| ファイル | スコープ | 今回の内容が収まるか |
|---|---|---|
| `directory-structure.md` | ディレクトリ構成・配置方針 | ✗ |
| `docs-workflow.md` | ドキュメントの置き場所・ライフサイクル | ✗ |
| `git-workflow.md` | ブランチ・コミット・PR/マージ運用 | ✗（hook誤検知の注意だけが接点） |
| `markdown-frontmatter.md` | markdownのfrontmatter規約 | ✗ |
| `powershell-encoding.md` | PowerShellの文字コード | ✗ |
| `shell-script-style.md` | **`.sh` として保存するスクリプト**の規約 | ✗（issue本文が明記するとおりスコープが異なる） |

**どのファイルにも収まらない。新規ファイルとする。**

`shell-script-style.md` は最も近いが、「保存されるスクリプトファイル」と「ツールへ渡す使い捨ての
コマンド文字列」では、寿命も読み手も違う。前者はレビューされ再実行されるが、後者は承認の一瞬だけ
読まれる。同じファイルに混ぜると、`set -euo pipefail` の宣言や `REPLY` への返却といった
スクリプト固有の規約が、1回限りのコマンドにも要求されるかのように読める。

### 命名

`.claude/rules/ai-command-style.md` を提案する。

- 既存の命名は kebab-case の主題名（`shell-script-style` / `git-workflow` / `docs-workflow`）。
- `shell-script-style` と対になる形で `ai-command-style` とすると、
  「保存するスクリプト」対「ツールへ渡すコマンド」の対比が名前から読める。

`frontmatter` は `.claude/rules/markdown-frontmatter.md` の規約に従い
`title` / `type: rule` / `description` / `tags` / `keywords` を付ける。**`alwaysApply: true` も
付ける**（調査1のとおり読み込みの条件ではないが、既存の運用critical な3ファイルが持っており、
他ハーネスが参照する可能性があるため揃える）。

## 設計への反映

### 受け入れ条件4の扱い（**要判断**）

受け入れ条件4は「複数行コマンドの1行目にはコメントを書かず、2行目以降に置くことが、**前方一致が
外れる理由とともに**明記されている」ことを求めている。しかし調査2のとおり、**この環境では
前方一致は外れない**。理由をそのまま書くと、ルールが事実でない根拠に立つことになる。

取りうる案は3つ。

| 案 | 内容 | 評価 |
|---|---|---|
| A | 制約自体を撤回する（1行目にコメントを書いてよい） | **推奨しない。** 測れたのは1環境・1バージョンだけで、ユーザーの常用環境では未確認。既存記録（issue #23）とも食い違っており、照合の実装が変わりうることを示している |
| B | 理由を「照合が外れる」から「**照合の実挙動が環境・バージョンで異なる観測がある**ため、先頭は避ける（リスク回避）」へ書き換える | **推奨。** 結論は変えずに、根拠を実測に合わせられる。受け入れ条件4の「理由とともに明記」も満たす（理由の中身が変わるだけ） |
| C | issueの記述どおり「前方一致が外れる」と書く | **不可。** 実測と食い違う記述をルールとして残すことになる |

**案Bを推奨する。** その場合、ルール本文には実測表（調査2のA〜D）を根拠として載せ、
「この環境では外れなかった」という事実も隠さずに書く。

### その他の反映

- **受け入れ条件1**: 新規ファイルでの実測が済むまで「満たした」と書かない（調査1）。
- **受け入れ条件5**（hook誤検知の再掲）: 仕組みの説明は `git-workflow.md` を参照し、
  コマンド内コメントの文脈での注意だけを書く。**コミット側と push 側で当てはまり方が違う**
  （調査3）ことにも触れる。
- **切り出し先**: scratchpad か `.claude/scripts/src/` かの判断基準を表に含める
  （`.claude/scripts/src/` は「skills経由で能動的に実行するスクリプト」の置き場であり、
  使い捨てを置くと配置ルールと衝突し、`cleanup-task.sh` の削除対象でもないため残り続ける）。

### 恒久的に残すべき知見（フェーズ4の候補）

このレポートは flow-id 5-3 で削除されるため、以下は `.claude/docs/` へ反映する候補になる。
**確定は flow-id 4-1 で行う。**

1. **`permissions` / `hooks[].if` の照合は部分コマンド単位である**という実測（調査2）。
   既存の `.claude/rules/git-workflow.md`「部分一致」という記述と食い違うため、
   **既存記述の訂正か、環境差の併記が要る**。
2. `block-direct-git-commit.sh` は `if` を経由しないため地の文で必ず発火する、という切り分け
   （調査3）。既存記述はこの区別を持っていない。
3. `.claude/rules/*.md` は `alwaysApply` の有無に関わらず読み込まれる（調査1）。
   `.claude/rules/markdown-frontmatter.md` は `alwaysApply` を
   「Claude Codeのルール常時適用設定として実際に使われる」と説明しており、**要確認**。
