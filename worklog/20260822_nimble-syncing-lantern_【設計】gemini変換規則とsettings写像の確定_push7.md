---
title: worklog: 【設計】gemini変換規則とsettings写像の確定（push7）
type: log
description: flow-id 3-6のA（一次情報の追加取得）でmatcher・環境変数解決・policy engineの3点を一次ソースで確定した記録と、jq不在時の扱いが2回差し戻された経緯
tags: [worklog, gemini, 設計, issue-70]
keywords: [matcher, matchesTrigger, SessionStartSource, resolveEnvVarsInString, GEMINI_PROJECT_DIR, policy-engine, Workspace層, jq, 前提チェック]
---

# worklog: 【設計】gemini変換規則とsettings写像の確定

対象: issue #70 / `.gemini/` を `.claude/` からの変換生成物にする（2026-08-22）。
全体作業計画: `plans/nimble-syncing-lantern.md`
個別作業計画: `plans/【設計】gemini変換規則とsettings写像の確定.md`
push回数: 7

## 試したこと

flow-id 3-6 の **A（一次情報の追加取得）**。既存クローン
（`/home/user/google-gemini/gemini-cli`、コミット `5411f113`）の sparse-checkout を広げた。
**クローンし直していない**（調査結果が引用している行番号がずれるため）。

```bash
git -C <clone> sparse-checkout add packages/core/src/hooks
git -C <clone> sparse-checkout add packages/cli/src/utils
```

`packages/core/src/config` は既に取得済みだったが、**探していた `settings.ts` はそこには無く**
`packages/cli/src/config/settings.ts` から `packages/cli/src/utils/envVarResolver.ts` を
呼んでいた。調査時点で置き場を取り違えていた。

## うまくいったこと

3件とも**一次ソースで確定した（S）**。うち2件は当初の見立てと違った。

### 5. SessionStart の `matcher` は縦棒つなぎが効かない（当初の見立てと違う）

`packages/core/src/hooks/hookPlanner.ts` の `matchesContext` が、**ツール名とトリガーで
別の判定を使い分けていた**。

| 判定対象 | 実装 | 帰結 |
|---|---|---|
| `context.toolName`（PreToolUse等） | `new RegExp(matcher).test(toolName)` | **正規表現。`Bash\|PowerShell` は効く** |
| `context.trigger`（SessionStart等） | `matcher === trigger` | **完全一致。`startup\|resume\|clear` は効かない** |

`fireSessionStartEvent` が `context = { trigger: source }` を渡していることも確認済み
（`hookEventHandler.ts` L183）。`source` の値は `SessionStartSource` enum の
`startup` / `resume` / `clear` の3つ（`types.ts` L607）。

**Claude側は `startup|resume|clear|compact` の4値**で、Geminiには `compact` に相当するソースが
無い（Geminiは `PreCompress` という別イベントを持つ）。

**したがって写像は「3エントリへ複製」ではなく「`matcher` を省略する」が正しい。**
`matchesContext` は `!entry.matcher` のとき無条件に `true` を返すため、省略＝全ソースで発火に
なる。Claude側が全ソースを覆っている今、これが最も短く、Geminiがソースを増やしても追随不要。
**フォールバック案として用意していた「単一値で複数エントリ登録」は採らない。**

ただし変換規則としては一般形で書く必要がある。**Claude の `matcher` を `|` で分割し、Gemini の
enum 値の集合と突き合わせる。全体を覆うなら `matcher` を落とし、部分集合なら値ごとにエントリを
複製する。** 今回は前者に当たる、という位置づけにする。

### 6. `${GEMINI_PROJECT_DIR}` が未定義でも空にはならない

`packages/cli/src/utils/envVarResolver.ts` の `resolveEnvVarsInString`。未定義かつ既定値が
無い場合は `return match;`、つまり**プレースホルダの文字列がそのまま残る**。
`/.gemini/hooks/...` のようなルート相対パスへ暴走することはない。

- **`${VAR:-DEFAULT}` 記法が使える**（正規表現 `\$(?:(\w+)|{([^}]+?)(?::-([^}]*))?})`）。
  安全側に倒すなら `${GEMINI_PROJECT_DIR:-.}` と書ける。写像表の選択肢として記録する。
- なお hook 実行時には `hookRunner.ts` L350 が `GEMINI_PROJECT_DIR: input.cwd` を渡しており、
  同 L527 が `$GEMINI_PROJECT_DIR` を**エスケープ済みcwdへ置換**している（コマンド
  インジェクション対策のテストもある）。**未定義になる経路は実質無い**。

### 7. policy engine の Workspace 層は現在無効（B-1の根拠が変わる）

`docs/reference/policy-engine.md` L126–L130 に警告がある。

> The **Workspace** tier (project-level policies) is currently non-functional.
> Defining policies in a workspace's `.gemini/policies` directory will not have any effect.
> See issue #18186. Use User or Admin policies instead.

優先度表（L144）でも Workspace 層に **(Currently disabled)** と明記されている。

**B-1（policy engine は本issueのスコープ外）の根拠が「選ばなかった」から「今は動かない」へ
変わる。** リポジトリへ `.gemini/policies/*.toml` を置いても効果がゼロなので、変換しても
無意味である。フェーズ4で spec へ理由を書くときは、**この事実（upstream issue #18186）を
根拠として書く**（「対応表が作れないから」ではない）。

### 副産物: `args` と `if` の裏取りができた（新発見ではない）

`.claude/settings.json` を読み直して2点確認した。**いったん「写像表に無い新発見」と書いたが誤りで、
どちらも調査レポートに既出だった**（`args` は行223、`if` は行227）。**新しいのは根拠の格だけで、
`docs/` 由来の D から、型定義を直接見た S へ上がった。**

- **`command` + `args` の分離が Gemini には無い。** Claude 側は
  `{"command": "bash", "args": ["${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh"]}` だが、Gemini の
  `CommandHookConfig`（`types.ts` L96–L105）は `command: string` の1本のみで **`args` を
  持たない**。**1つの文字列へ連結する変換が要る**（引用符付けの規則も決める必要がある）。
- **`if` フィールド（`.claude/settings.json` の PostToolUse が持つ、実行コマンドで絞り込む
  キー）が Gemini には無い。** `CommandHookConfig` の
  キーは `type`/`command`/`action`/`name`/`description`/`timeout`/`source`/`env` のみ。
  PostToolUse の4エントリがこれに依存しているため、**落とすと当該操作以外でも
  レポート系hookが毎回走る**。写像を決める必要がある。

## ダメだったこと

- **`packages/core/src/config` を取りに行ったが空振りだった。** 探していた `settings.ts` は
  `packages/cli/src/config/` にあり、しかも実体は `packages/cli/src/utils/envVarResolver.ts`
  だった。調査時点で「`packages/core/src/config/settings.ts` の `resolveEnvVarsInObject`」と
  書いていたのが誤りで、**調査結果の該当箇所を直す必要がある**。

## 次の一歩

- 上記5・6・7を `reports/20260822_nimble-syncing-lantern_gemini同期方式の調査.md` へ
  **S（一次ソース）** として反映し、`.html` も同期する
- **`args` の連結規則（引用符付け）と `if` の写像は、依然として未決である。** 差分の存在は
  調査レポートが既に書いているが、**どう変換するか**は決まっていない。実装時に暗黙で決めない
- そのうえで実装（変更対象11件）へ入る

---

## 追記: `jq` 不在時の扱いが2回差し戻された（チャット・2026-08-22）

| 版 | 内容 | 差し戻された理由 |
|---|---|---|
| 当初 | `jq` が無ければ**生成をスキップして警告**（インストールは成功扱い） | 沈黙する。`.gemini/` が丸ごと無くても配布先が気づけない |
| 2版 | **警告しつつ生成**（部分生成を残す） | `jq` が無ければ機構全体が動かないのだから、部分生成も嘘の成功である |
| **確定** | **`jq` が無ければエラーで止め、インストールを促す** | — |

**自分の書いた前提と、自分の設計が矛盾していた。** 2版を書くときに
「`jq` は `.claude/` 機構全体の前提（`Provider.sh`・`extract-frontmatter.sh`・hookが依存）」と
明記しておきながら、**その前提が満たされない状態で処理を続ける設計**にしていた。前提が前提なら、
満たされない時点で止めるのが筋である。

**確定した挙動**: `install-to-project.sh` は**冒頭の前提チェック**で `jq` を確認し、無ければ
**何も書き込まずに**非0で終了する（途中まで書いて止まる形を作らない）。`sync-gemini-assets.sh`
自身も単体で呼ばれるため同じチェックを持つ。**エラーメッセージにはOS別の導入コマンドを含める**
（`jq: command not found` だけでは何を入れればよいか分からない）。

テストは **T10**（`PATH` を差し替えたスタブで `jq` を隠し、非0終了かつ何も生成しないこと）を追加した。
