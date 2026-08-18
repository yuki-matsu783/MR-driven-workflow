---
title: 【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化
type: plan
description: issue #23の個別作業計画。UsageTracking.shのミラーをセッション単位へ統合し、push断面をpush-index.jsonlの行番号記録へ置き換え、logs/系統を廃止する
tags: [usage-report, session-logs, hooks, testing]
keywords: [push-index, session-logs, UsageTracking, sync_usage_state, engine分岐, Gemini CLI, show-push-log, test_usage_tracking, 行範囲, カーソル]
---

# 【設計】【実装】【テスト】セッションログのミラー統合とpush断面インデックス化

- issue: #23 / Draft PR: #24
- 全体作業計画: `plans/snoopy-petting-puddle.md`

種別を1ファイルに併記した理由: 設計・実装・テストが一体で判断でき、フェーズごとに合意を分ける
必要がないため（`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 設計

### 現在の呼び出し構造

```
post-push-usage-report.sh main()
  ├─ engine判定（tool_name → claude / gemini）※engineは署名表示にしか使っていない
  └─ sync_usage_state repo_root branch session_id transcript_path
       ├─ _usage_read_cursor        repo_root session_id            → last_line_count
       ├─ _usage_aggregate_new_lines transcript last_line_count branch → {totalLines, delta...}
       ├─ （新規行が無ければここで打ち切り）
       ├─ _usage_sync_session_logs  repo_root branch session_id transcript_path → log_dir
       ├─ _usage_aggregate_transcript log_dir/main.jsonl branch     → activeSeconds
       ├─ _usage_merge_state                                        → new_state
       ├─ _usage_aggregate_and_merge_subagents new_state log_dir branch repo_root → new_state
       └─ _usage_write_cursor       repo_root session_id total_lines

post-push-save-logs.sh main()   ← 別hook。logs/push-<N>/ へ全文コピー（廃止対象）
```

### 変更後の構造

```
post-push-usage-report.sh main()
  └─ sync_usage_state repo_root branch session_id transcript_path engine   ← engineを渡す
       ├─ _usage_read_cursor
       ├─ _usage_aggregate_new_lines
       ├─ _usage_sync_session_logs repo_root session_id transcript_path engine  ← branch廃止・engine追加
       ├─ _usage_aggregate_transcript
       ├─ _usage_merge_state
       ├─ _usage_aggregate_and_merge_subagents → {state, agents:{<id>:{from,to}}}  ← 戻り値変更
       ├─ _usage_append_push_index                                          ← 新規
       └─ _usage_write_cursor
```

### 変更1: `_usage_sync_session_logs`（ミラーのセッション単位化＋engine分岐）

| | 変更前 | 変更後 |
|---|---|---|
| 引数 | `repo_root branch session_id transcript_path` | `repo_root session_id transcript_path [engine]` |
| コピー先 | `usage/session-logs/<safeBranch>/<sessionId>/` | `usage/session-logs/<sessionId>/` |
| engine分岐 | 無し（Claude Code構造のみ） | `claude` / `gemini` |

`engine` は省略時 `claude`（既存の呼び出し・テストを壊さないため）。

| engine | 探索元 | コピー先 |
|---|---|---|
| `claude` | `${transcript_path%.jsonl}/subagents/agent-*.jsonl` ＋ 対応する `.meta.json` | `subagents/` 直下（変更なし） |
| `gemini` | `$(dirname "$transcript_path")/<session_id>/`（ディレクトリごと） | `subagents/<session_id>/` |

`branch` を引数から外せる根拠: この関数は `branch` をコピー先パスの組み立てにしか使っていない。
集計側のブランチフィルタは `_usage_aggregate_new_lines` / `_usage_aggregate_transcript` が
それぞれ独立に `branch` を受け取って行うため、ミラーの置き場所とは無関係である。

**Gemini分を1階層下（`subagents/<session_id>/`）へ置く理由**: 集計側
`_usage_aggregate_and_merge_subagents` の glob は `"$subagents_dir"/agent-*.jsonl` であり、
`subagents/<session_id>/` というディレクトリにはマッチしない。「Geminiのログは保存するが集計対象には
しない」という本issueのスコープ境界が、追加のガード条件を書かずに構造だけで保証される。

```bash
_usage_sync_session_logs() {
  local repo_root="$1" session_id="$2" transcript_path="$3" engine="${4:-claude}"

  local log_dir="${repo_root}/usage/session-logs/${session_id}"
  mkdir -p "${log_dir}/subagents"
  cp "$transcript_path" "${log_dir}/main.jsonl"

  if [ "$engine" = "gemini" ]; then
    # Gemini CLI: transcript_pathのあるディレクトリ配下の、session_idと同名ディレクトリが
    # サブエージェントログ（post-push-save-logs.sh から移植。未検証の前提はDDR参照）
    local subagents_src="$(dirname "$transcript_path")/${session_id}"
    if [ -n "$session_id" ] && [ -d "$subagents_src" ]; then
      cp -R "$subagents_src" "${log_dir}/subagents/" 2>/dev/null || true
    fi
  else
    local session_dir="${transcript_path%.jsonl}"
    if [ -d "${session_dir}/subagents" ]; then
      local f meta
      for f in "${session_dir}/subagents"/agent-*.jsonl; do
        [ -e "$f" ] || continue
        cp "$f" "${log_dir}/subagents/" 2>/dev/null || true
        meta="${f%.jsonl}.meta.json"
        [ -f "$meta" ] && cp "$meta" "${log_dir}/subagents/" 2>/dev/null || true
      done
    fi
  fi

  printf '%s' "$log_dir"
}
```

### 変更2: `_usage_aggregate_and_merge_subagents`（戻り値に行範囲を追加）

push-index へ `agents` を記録するため、戻り値を状態JSON単体から
`{state: <状態JSON>, agents: {<agentId>: {from, to}}}` へ変更する。呼び出しは
`sync_usage_state` の1箇所のみで、影響は閉じている。

ループ内で、そのagentを実際に集計した（`total_lines > last_line_count`）場合のみ
`{from: last_line_count + 1, to: total_lines}` を積む。スキップしたagentは `agents` に現れない。

### 変更3: `_usage_append_push_index`（新規）

```bash
_usage_append_push_index() {
  local repo_root="$1" branch="$2" session_id="$3" engine="$4"
  local main_from="$5" main_to="$6" agent_ranges="$7"

  local state_dir="${repo_root}/usage/state"
  local index_file="${state_dir}/push-index.jsonl"
  mkdir -p "$state_dir"

  # 既存の最大push番号+1（post-push-save-logs.shのpush-<N>連番決定と同じ「常に最大値+1」方針。
  # 行数ではなく値のmaxを見るため、手動編集・末尾改行の欠落があっても壊れない）
  local push_num=1
  if [ -f "$index_file" ] && [ -s "$index_file" ]; then
    push_num="$(jq -s '[.[].push // 0] | (max // 0) + 1' "$index_file" 2>/dev/null || printf '1')"
  fi

  jq -c -n --argjson push "$push_num" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg branch "$branch" --arg sessionId "$session_id" --arg engine "$engine" \
    --argjson from "$main_from" --argjson to "$main_to" --argjson agents "$agent_ranges" '
    {push: $push, at: $at, branch: $branch, sessionId: $sessionId, engine: $engine,
     main: {from: $from, to: $to}, agents: $agents}
  ' | tr -d '\r' >> "$index_file"
}
```

- 出力行の例:
  `{"push":12,"at":"2026-08-18T12:34:56Z","branch":"feature-23-...","sessionId":"8f1e...","engine":"claude","main":{"from":699,"to":883},"agents":{"a2f64f10a7c680386":{"from":1,"to":120}}}`
- **`tr -d '\r'`**: WindowsネイティブjqがファイルリダイレクトでCRを付与するため
  （`.claude/rules/shell-script-style.md`「文字コード」節）。
- 行番号は**1始まり・両端含む**。基準は既存集計と同じ「空行を除いた行数」
  （`_usage_aggregate_new_lines` の `select(length > 0)`）。

### 変更4: `sync_usage_state`（engine受け取り・push-index追記）

- 引数に `engine`（第5、既定 `claude`）を追加。
- `_usage_sync_session_logs` の呼び出しを新シグネチャへ。
- サブエージェント集計の戻り値から `state` / `agents` を取り出す。
- 状態ファイル書き込み後、`_usage_append_push_index` を呼ぶ。
- **新規行が無い場合の早期リターンは変更しない**（push-indexにも行を追加しない。
  「差分がなければ何もしない」という issue #37 の設計を維持する）。

### 変更5: `post-push-usage-report.sh`

`sync_usage_state` 呼び出しに `"$engine"` を追加するのみ。これまで `engine` は
フッター署名（`engine_label`）にしか使われていなかった。

### 変更6: `logs/` 系統の廃止

| 対象 | 操作 |
|---|---|
| `.claude/hooks/post-push-save-logs.sh` | 削除 |
| `.claude/settings.json` | `hooks.PostToolUse[0].hooks` から `post-push-save-logs.sh` の2エントリを削除 |
| `.gemini/settings.json` | `AfterTool` から `post-push-save-logs` エントリを削除 |
| `.gitignore` | `/logs/` の行とコメントを削除 |
| ローカルの `logs/`（14MB・13断面） | 削除（gitignore対象・読み手なし・再生成可能） |
| ローカルの `usage/session-logs/<safeBranch>/`（旧レイアウト） | 削除（同上。次回pushで新レイアウトへ再生成される） |

### 変更7: `.claude/scripts/src/show-push-log.sh`（新規）

```
使い方:
  show-push-log.sh              # push一覧（push番号・日時・ブランチ・行範囲）を表示
  show-push-log.sh <push番号>   # そのpushで新たに記録された範囲のログ本文を出力
  show-push-log.sh <push番号> --agents   # 同じ範囲のサブエージェント分もあわせて出力
```

`usage/state/push-index.jsonl` から該当エントリを引き、
`usage/session-logs/<sessionId>/main.jsonl` の `main.from`〜`main.to` 行を出力する。
ミラーが存在しない場合はその旨をstderrへ出して終了コード1。

## 実装手順

1. `.claude/hooks/lib/UsageTracking.sh` を変更する（変更1〜4）。ファイル冒頭のコメント群にも、
   ミラーがセッション単位になったこと・push-indexの追加・engine分岐を追記する。
2. `.claude/hooks/post-push-usage-report.sh` を変更する（変更5）。
3. `.claude/scripts/src/show-push-log.sh` を新規作成する（変更7）。
4. `tests/test_usage_tracking.sh` を新規作成する（下記「テスト」）。
5. `logs/` 系統を廃止する（変更6）。ローカルディレクトリの削除は最後に行う。
6. `bash -n` で構文チェック → 単体テスト → 実データでの回帰確認。

## テスト

`tests/test_usage_tracking.sh` を新設する。規約は `tests/test_extract_frontmatter.sh` に合わせる
（`mktemp -d` のフィクスチャ＋`trap`、`assert_eq`、`passed=N failures=N` を出力し失敗時に終了コード1、
`main` を実行せずsourceできる形）。

| # | 対象 | 検証内容 |
|---|---|---|
| 1 | `_usage_append_push_index` | ファイルが無い状態で `push=1` の行が作られる |
| 2 | 〃 | 2回目の呼び出しで `push=2` になる（最大値+1） |
| 3 | 〃 | `main.from` / `main.to` / `branch` / `sessionId` / `engine` が渡した値どおり |
| 4 | 〃 | `agents` が渡したオブジェクトどおりに記録される |
| 5 | 〃 | 出力行に CR が混入していない |
| 6 | `_usage_sync_session_logs`(claude) | コピー先が `usage/session-logs/<sessionId>/` である（ブランチ階層が無い） |
| 7 | 〃 | `agent-*.jsonl` と `.meta.json` が `subagents/` 直下へコピーされる |
| 8 | `_usage_sync_session_logs`(gemini) | `subagents/<session_id>/` 配下へコピーされる |
| 9 | 〃 | Gemini分が集計側の glob `subagents/agent-*.jsonl` にマッチしない |
| 10 | `_usage_aggregate_and_merge_subagents` | 戻り値が `{state, agents}` の形である |
| 11 | 〃 | 新規行があるagentだけが `agents` に現れる（スキップしたagentは含まれない） |
| 12 | `sync_usage_state` | フィクスチャのtranscriptで、新レイアウトのミラー・push-index・カーソルが揃って更新される |
| 13 | 〃 | 新規行が無い2回目の呼び出しでは push-index が増えない |

## 検証（実データ）

1. 本ブランチで実際にpushし、次を確認する。
   - `usage/session-logs/<sessionId>/main.jsonl` が作られる（ブランチ階層が無い）
   - `usage/state/push-index.jsonl` に行範囲が追記される
   - `logs/` が再生成されない
   - PR #24 へ対応工数レポートが従来と同じ体裁で投稿される
2. `show-push-log.sh <N>` の出力が、`push-index.jsonl` の範囲に対する
   `sed -n 'from,top' usage/session-logs/<sessionId>/main.jsonl` と一致する。
3. `show-push-log.sh` の引数なし実行でpush一覧が表示される。

## 併せて確認する事項

`.claude/settings.json` の `if: "Bash(git push*)"` が前方一致か部分一致かを実挙動で確認する
（issue #23 のコメント参照。仕様書は前方一致と説明しているが、`cd ...` で始まるコマンドで
発火した実績がある）。確認結果はフェーズ4で `spec/issue-mr-workflow.md` へ反映する。

## やらないこと

- Geminiサブエージェントを対応工数の集計対象に含めること。
- ネストしたサブエージェント（depth 2以降）への対応。
- `activeSeconds` の算出方式の変更。
- `usage/session-logs/` の保持期間・自動削除ポリシー。
- 旧レイアウトからのデータ移行（gitignore対象のキャッシュのため、削除して作り直す）。
