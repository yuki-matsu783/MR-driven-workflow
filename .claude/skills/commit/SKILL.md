---
name: commit
description: 'Generate a Japanese commit message with Conventional Commits prefix and create one or more atomic commits. Use whenever a commit needs to be made in this repository — both when the user explicitly invokes /commit AND whenever an AI agent commits autonomously as part of the issue-mr-flow (flow-id 2-2/2-7/3-2/3-7/4-2/4-7/5-4/5-6). All commits in this repo MUST go through this skill; direct git commit is blocked by a PreToolUse hook. Flow: git status → analyze diff → filter sensitive/junk files → .claude/scripts/src/create-commit.sh (NO Claude footer, no confirmation; multiple mixed prefixes are auto-split into separate commits)'
title: git commit標準化
type: skill
tags: [issue-mr-flow, workflow, skill]
keywords: [commit, コミット]
---

# /commit スキル

`/commit` が呼ばれた時、変更内容を分析して日本語のコミットメッセージを自動生成し、確認を挟まずコミット作成まで進める。

## 呼び出しタイミング

このスキルは以下の2パターンいずれでも使う（issue #39: 「すべてのコミットがスキルを利用して
行われる」が受け入れ条件）。

- ユーザーが明示的に `/commit` と入力した場合
- AIエージェントが本リポジトリでコミットを作成する場面全般
  （`.claude/skills/issue-mr-flow/SKILL.md` の全体フローflow-id 2-2/2-7/3-2/3-7/4-2/4-7/5-4/5-6
  「commit, push してレビュー依頼を行う」等）

`git commit` の直接実行は `.claude/hooks/block-direct-git-commit.sh`（PreToolUse hook）により
機構的にブロックされる（`.claude/rules/git-workflow.md` の「コミット運用」節参照）。このスキルの
Step 4は `.claude/scripts/src/create-commit.sh` というラッパースクリプト経由でコミットするため、
hookの対象にならず正規に実行できる。

## 絶対ルール

- **`Co-Authored-By: Claude` などのフッターは絶対に付けない**
- **`git add .` / `git add -A` は使わない** — 必ず個別ファイル指定
- **`--no-verify` は使わない**（フックが失敗したら原因を直す）
- **`git commit --amend` は使わない**（常に新規コミット）
- **失敗時に `git reset` などで自動ロールバックしない** — 状況を報告してユーザに判断を仰ぐ
- **ステージングされていない変更（unstaged / untracked）はコミット対象に含めない** — ユーザに質問せず自動的に除外する。コミット対象は `git diff --cached` で確認できるステージング済み変更のみ

**削除したファイルのパスは、他のファイルと同じように `--` の後ろへ並べてよい**（issue #60）。
追跡済みファイルを削除しただけのパスは、ラッパーがそのまま「削除」としてステージする。
**先に削除をステージしてから残りをラッパーへ渡す2段構えは不要**であり、むしろそれを行うと
当該パスがindexから消えるため、後続の処理がpathspec不一致で失敗する。既に削除がステージ済みの
パスを渡した場合は、冪等にスキップして通知するだけになる
（仕様: `.claude/docs/spec/create-commit.md`、経緯: `.claude/docs/ddr/i0060-01-create-commitは削除ステージ済みパスをgit-addの失敗時分類で吸収する.md`）。

## 実行フロー

### Step 1: 現状把握

並列で以下を実行：

- `git status`（`-uall` フラグは使わない）— ステージング状態の確認用
- `git diff --cached`（**staged のみ**。unstaged は対象外なので見ない）
- `git log --oneline -10`（リポジトリのコミットスタイル参考用）

**ステージング済みの変更が1つもない場合**は「ステージング済みの変更がありません。`git add` でコミット対象をステージングしてください」と伝えて終了する。unstaged/untracked のファイルが残っていても**ユーザに質問しない**（自動的にコミット対象外として扱う）。

### Step 2: 変更内容を分析

取得した diff から以下を判定：

**(a) prefix判定** — 各変更ファイル群に対して以下から選ぶ：

| prefix | 意味 |
|---|---|
| `feat` | 新機能の追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメントのみの変更 |
| `ai-asset` | AIアセットの変更。対象は**AIが読むもの**（`.claude/rules/` `.claude/skills/` `.claude/agents/` `AGENTS.md` `CLAUDE.md` `GEMINI.md`）。**`.claude/scripts/` は対象外**で、単体テストを持つ実装コードとして `feat`/`fix`/`refactor` を使う（線引きは `.claude/skills/issue-mr-flow/references/planning.md` の `【AIアセット作成】` の定義と同じ） |
| `style` | コードの意味に影響しない変更（空白・フォーマット等） |
| `refactor` | バグ修正でも機能追加でもないコード変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド補助ツール・雑務（`build` 以外） |
| `perf` | パフォーマンス改善 |
| `ci` | CI設定の変更 |
| `build` | ビルドシステム・外部依存の変更 |
| `revert` | 以前のコミットの取り消し |

**(b) 論理的まとまり判定** — 内容（prefixが変わるか）+ ファイルパスの両方を見て、複数のスコープに分かれるかを判定。

### Step 3: ファイルフィルタ

`git add` 対象から以下を**自動除外**：

**クレデンシャル系（絶対除外）**
- `.env`, `.env.*`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.ppk`
- `credentials.json`, `service-account*.json`
- `id_rsa`, `id_ed25519`, `id_ecdsa`
- `.aws/credentials`, `.netrc`
- `secrets.yml`, `secrets.yaml`

**開発環境の副産物**
- `.DS_Store`, `Thumbs.db`, `desktop.ini`
- `*.swp`, `*.swo`, `*~`
- `node_modules/`, `vendor/`, `__pycache__/`
- `dist/`, `build/`, `out/`, `target/`
- `*.pyc`, `*.class`, `*.o`
- `*.log`, `logs/`
- `tmp/`, `temp/`, `*.tmp`, `*.bak`, `*.orig`
- `*.stackdump`（MSYS/git bashのクラッシュダンプ。issue #127で実際にコミットしてしまった）
- `settings.local.json`（`.claude/settings.local.json` 等の、環境依存値を持つローカル
  オーバーライド設定。issue #70。**このリポジトリの `.gitignore` には既に入っているが、
  それだけでは配布先を守れない**ため、配布に乗るこちらにも置く）

**このリストに無い新種の副産物は素通りする。** 呼び出し側が `git status` の出力を機械的に全件
渡す運用だと、そのぶんだけリストが実質的な最後の砦になる。新種を見つけたら**このリストと
`.gitignore` の両方**へ追加する（`.gitignore` はこのリポジトリ限定の対処だが、このリストは
`.claude/` ごと他プロジェクトへ配布される。`.claude/rules/git-workflow.md`「コミット運用」）。

**削除されたファイルは除外対象ではない**（issue #60）。`git status` の `D`（deleted）で
表れているパスも、通常の変更と同じようにコミット対象へ含めてよい。

**除外したファイルがあれば**、コミット実行前にチャットに明示：
```
以下は自動除外しました（コミットには含めません）：
- .DS_Store
- node_modules/...
```

### Step 4: コミット実行

**確認は挟まず、そのままコミットを作成する。** ユーザへの承認待ち（AskUserQuestion等）は行わない。

**単一スコープの場合：** 提案するコミットメッセージをチャット本文に表示したうえで、そのまま
コミットを実行する。除外予定のファイル（クレデンシャル系・副産物）があれば合わせて明示する。

**複数prefix混在の場合：** 確認を挟まず、prefixごとに複数コミットへ自動的に分割して順次実行する。
実行前に、分割案をチャット本文に明示する（透明性のため。承認待ちはしない）：
```
コミット1: feat: ○○機能を追加
  - src/feature.ts
  - src/feature.test.ts
コミット2: docs: READMEを更新
  - README.md
```

`git commit` を直接実行せず、`.claude/scripts/src/create-commit.sh` を使う
（`git commit` の直接実行は `.claude/hooks/block-direct-git-commit.sh` によりブロックされる）。

```
bash .claude/scripts/src/create-commit.sh --message "<prefix>: <日本語説明>" -- <file1> [file2 ...]
```

**コミットメッセージの書き方は、下記「コミットメッセージの内容規約」に従う。**

複数コミットの場合は順番に Step 3-4 を繰り返す。途中で失敗したら**そこで停止**して状況を報告（自動 reset しない）。

## コミットメッセージの内容規約

**目的は「squash merge後に `main` へ残るログだけで、何を・どう変えたかを追える」ことである**
（issue #185）。prefixと対象名だけでは、後から読む人に何も伝わらない。

### 件名（1行目）の形式

```
<prefix>: <日本語説明>
```

**件名は必須。1行で書く。** 満たすべき要素は次の3つ。

| 要素 | 内容 | 省略 |
|---|---|---|
| **何を** | 変更した対象（ファイル・機能・概念） | **不可** |
| **どう** | どう変えたか（変更後の状態・採った手段・変わった値） | **不可** |
| **なぜ** | 変更の理由 | 対象と手段から自明なら可。本文へ回してもよい |

#### 「どう」を書けていない件名の判定

**次の6語のいずれかで終わる件名は不合格。** 対象を述べただけで、どう変えたかを述べていない。

```
修正 / 更新 / 反映 / 追加 / 作成 / 記録
```

語尾は **「〜する」「〜した」「体言止め（〜を更新）」のいずれも対象**とする。

```bash
# 不合格を機械的に拾う（issue #185 の調査では、直近5件のsquashに畳まれた80件のうち51件＝64%が該当した）
grep -cE '(を|の)?(修正|更新|反映|追加|作成|記録)(する|)$'
```

**「件数だけ」で終わる件名も同じく不合格。** 「指摘18件を反映」は、何件直したかしか伝えない。

### 良い例・悪い例

| | 件名 | 判定の理由 |
|---|---|---|
| 悪い | `docs: HANDOFFを更新` | **どう**が無い。対象＋動詞で終わっている |
| 良い | `docs: HANDOFFのflow-id 3-6完了とpush回数6を記録` | 何が何になったかが分かる |
| 悪い | `docs: 敵対的レビュー2回目の指摘18件を調査結果へ反映` | 件数しか伝えていない。**どう**直したかが無い |
| 良い | `docs: 敵対的レビュー2回目の9件へ対応（Q4「実測不能」の撤回・母数から本文を分離）` | 何を・どう直したかが分かる |
| 悪い | `ai-asset: タスク種別の定義矛盾を修正` | どこがどう矛盾していて、どう直したのかが無い |
| 良い | `ai-asset: タスク種別の【AIアセット作成】がフェーズ3と4の両方に属していた記述をフェーズ3へ一本化` | 矛盾の中身と解消後の状態が分かる |

**悪い例は「短いから」悪いのではない。** 長くても中身が無い件名は同じく不合格である
（issue #185 の調査では、最長103文字の件名が「良い例」だった）。

### 本文（2行目以降）

**任意。件名だけでは上記の3要素を満たせないときに書く。**

- 件名の次に**空行を1行**置き、その後に本文を書く（`git commit -m` の仕様）。
- 「必ず本文を書け」とは求めない。**件名で足りるなら件名だけでよい。**
- **本文はsquash merge後も `main` の履歴へ恒久的に残る**（`* 件名` → 空行 → 本文 の形で畳まれる。
  issue #185 の調査で実測）。`wip/` 配下のように後で消える置き場とは違う。
- 書くとよい内容: 何を根拠に判断したか／却下した案／確認した結果（件数と対処の内訳）／
  既知の未確認事項。

```bash
bash .claude/scripts/src/create-commit.sh --message "$(cat <<'MSG'
fix: 検証コマンドの--の位置誤りでgrepのフィルタが無効だった件を-e指定へ修正

`grep -rn -- 'pattern' --include='*.md' path` は、`--` 以降が非オプション扱いに
なるため `--include` が検索対象ファイル名として渡り、フィルタが1つも効かない。
オプションを先に置き、パターンは `-e` で渡す形へ直した。
MSG
)" -- path/to/file
```

### フッター

| フッター | 扱い |
|---|---|
| `Refs #NNN` のような**追跡用**フッター | **許容する**。人間が書いても同じ形になる情報のため |
| `Co-Authored-By: Claude` 等、**AIの生成物であることを示す**フッター | **絶対に付けない**（上記「絶対ルール」） |
| モデル名・モデルIDを含む記述 | **絶対に付けない**（コミットメッセージに限らず、リポジトリへ入る成果物すべて） |

### 成果物の変更を伴わないコミット

`HANDOFF.md` の進捗更新・作業中ドキュメントのみの変更・空コミットは、**`main` に残らない対象を
扱うコミットだが、コミットログ自体は `main` に残る**。次の形で書く。

| 類型 | 悪い例 | 求める形 |
|---|---|---|
| `HANDOFF.md` の進捗更新のみ | `docs: HANDOFFを更新` | **どのflow-idが何になったか**を書く<br>例: `docs: HANDOFFのflow-id 2-10完了とpush回数5を記録` |
| 計画・worklog・レポートのみの変更 | `docs: 計画を修正` | **どの節・どの判断が変わったか**を書く<br>例: `docs: 個別作業計画へフッター全般の可否を決定1-bとして追加` |
| Draft PR作成のための空コミット | — | **現状の形でよい**（例外）<br>例: `chore: Draft PR作成のための空コミット（baseとの差分が無いため）` |

### 判断に迷ったときの既定

| 迷い | 既定 |
|---|---|
| 件名に収まりきらない | **本文へ書く**（件名を削るより、本文を足す） |
| 「なぜ」を書くべきか分からない | **書く**（自明かどうかの判断を、読み手ではなく書き手が引き受ける） |
| prefixが複数にまたがる | **コミットを分ける**（Step 2-(b) の論理的まとまり判定） |
| 「どう」が長くなり列挙になる | **代表的な変更を件名へ書き、全体像は本文へ**（件数だけの件名にしない） |
| 上の6語で終わってしまう | **その動詞の目的語ではなく、変更後の状態を書く**（「〜を更新」→「〜が〜になった」） |

### 注記: `git log --oneline` に出るのはPRタイトルである

squash mergeされたリポジトリでは、**`main` の1行ログに現れるのはPRタイトル + ` (#PR番号)`** で
あり、個々のコミットの件名は**squashコミットの本文の中**に `* 件名` として並ぶ
（issue #185 の調査で実測）。

- したがって、**この規約を守ってもコミット件名が `--oneline` に出るようにはならない。**
  効くのは「squash本文を開いたとき」「ブランチ上の履歴を追うとき」である。
- 1行ログの読みやすさはPRタイトルの問題であり、本規約の対象外である。

## 備考
<レビュアーが知っておくべきこと、未対応事項。なければセクション省略>
```

**条件付きで以下を追加（該当時のみセクション追加、なければ省略）：**

- **関連Issue**：コミットメッセージや diff コメントに `#123` などの参照があれば
  ```markdown
  ## 関連
  - Closes #123
  ```

- **破壊的変更**：API・公開インターフェイスの非互換変更を検知したら
  ```markdown
  ## 破壊的変更
  - <何が変わったか・移行方法>
  ```

**変更内容の列挙ルール：**
- 主要ファイルのみ列挙（大量にある場合はディレクトリ単位で要約）
- 自動除外したファイルは含めない

## エラー時の対応

- **pre-commitフック失敗** → エラーを表示し、原因を修正してから新規コミットを作る（amend禁止）
- **複数コミット中に失敗** → そこで停止、`git status` で現状を表示してユーザに判断を仰ぐ
- **コミット対象がない** → 「コミットする変更がありません」と伝えて終了

## してはいけないこと

- TodoWrite / Agent ツールの使用
