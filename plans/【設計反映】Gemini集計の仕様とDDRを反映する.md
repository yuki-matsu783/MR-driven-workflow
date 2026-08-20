---
title: 【設計反映】Gemini集計の仕様とDDRを反映する
type: plan
description: issue #97の調査・実装で確定した設計判断を、.claude/docs/spec と .claude/docs/ddr へ反映するための個別反映計画
tags: [usage-report, gemini-cli, spec, ddr]
keywords: [issue-mr-workflow, 対応工数レポート, DDR, 未決定事項, 影響範囲, 畳み込み, ブランチ帰属, トークン列, rewindTo]
---

# 個別反映計画: Gemini集計の仕様とDDRを反映する（issue #97 フェーズ4）

- issue: [#97](https://github.com/yuki-matsu783/MR-driven-workflow/issues/97)
- PR: [#101](https://github.com/yuki-matsu783/MR-driven-workflow/pull/101)（Draft）
- 全体作業計画: `plans/partitioned-forging-seahorse.md`
- 反映元: `reports/20260820_partitioned-forging-seahorse_Geminiセッションログの調査.md`（フェーズ2）、
  `reports/20260820_partitioned-forging-seahorse_Gemini集計の実装.md`（フェーズ3）、
  `worklog/20260820_..._push6.md`

**本ファイルには「これから何をするか」だけを書く。実施結果は
`reports/日付_partitioned-forging-seahorse_設計反映.md` へ記録する**
（`.claude/skills/issue-mr-flow/SKILL.md`「計画と実施結果の分離」）。

**`【AIアセット反映】` は別ファイル**（`plans/【AIアセット反映】Gemini集計で得た教訓を反映する.md`）
とし、本計画の合意・実施が終わってから着手する（評価軸が混ざるため。
`.claude/skills/issue-mr-flow/SKILL.md`「種別を複数併記する場合／分ける場合」）。

## 目的

issue #97 で確定した設計判断を、**現在の正史**（`spec`）と**意思決定の記録**（`ddr`）へ落とす。
コードを読んだだけでは分からない「なぜそうしたか」「何を検討して捨てたか」を、この機会にしか
残せないため。

## 反映対象（flow-id 4-1 で洗い出した結果）

### 1. `.claude/docs/spec/issue-mr-workflow.md`

| 箇所 | 変更 |
|---|---|
| L839 付近「**Gemini CLIはミラーへの保存のみ対応し、対応工数の集計対象には含めない**（issue #23）」 | **記述を分割する。** メインセッションは集計対象になった（issue #97）が、**サブエージェントは引き続き保存のみ**である（設計判断I）。現行の文はこの2つを区別していないため、そのままでは誤りになる。`subagents/agent-*.jsonl` のglobが構造的にマッチしないという説明自体は、サブエージェント側の記述として残す |
| **「コンポーネント」（L869〜）** | **Gemini経路の分岐と新設関数を追記する。** 現行は「まず `_usage_read_cursor` でカーソルを読み…」とClaude Code経路だけを唯一の流れとして書いており、engine分岐の存在に気づけない（「新規行が無ければ早期リターン」がGeminiにも当てはまると誤読する）。追記するのは `_usage_gemini_fold` / `_usage_gemini_merge_state` / `_usage_read_gemini_totals` / `_usage_write_gemini_totals` / `_sync_usage_state_gemini` の5本と、`post-push-usage-report.sh` から切り出した `build_usage_report_body` |
| 「対応工数レポート」節（L647〜） | **Gemini CLI経路の小節を新設**する。内容は下表「specへ書く内容」 |
| 「未決定事項・懸念点」（L2554付近） | (a) **実機未検証の4点を追加**（`reports/…実装.md`「未検証として残る範囲」）。(b) 既存の「Gemini CLI側のサブエージェント探索の前提が実態と合っていない可能性（親と同じセッションIDで動作するとの報告）」は、フェーズ2の調査で**本体実装側から裏付けが取れた**ため、決定済みとして扱えるかを判断して書き換える |
| 「影響範囲」（L1270〜） | **issue #97 のエントリを新規追加**する。**既存エントリは1文字も変更しない**（point-in-timeの記録。`.claude/rules/docs-workflow.md`） |

**specへ書く内容**（「対応工数レポート」節の新小節）

- 差分の取り方: 毎回ファイル全体をid単位で畳み、**前回累計との差分**を取る。Claude Code経路の
  行カーソル方式は使わない。
- 前回累計の置き場所: `usage/state/gemini-totals/<sessionId>.json`（**ブランチ非依存**）。
- 消失検知: 1指標でも負なら `needsReset`。クランプ前（raw）の差分で早期リターンを判定する。
- レコード種別（メッセージ／`$set`／`$rewindTo`）の扱い。
- ツールの status の扱い（`error` のみエラー、`cancelled` は実行回数、未完了はどちらにも入れない）。
- **応答回数・使用モデルの算出**（畳み込み後のユニークid数／`model` の集合）。issue #97 の
  期待する動作2に挙がっている集計項目であり、書かないと正史から漏れる。
- **稼働時間の算出**（設計判断Q）。**既存の「稼働時間の算出方法」節がGeminiにも当てはまるかを
  明示する。** 算出方式は同一（gap積算＋末尾 `TAIL_BUFFER_SECONDS` の加算まで含む）だが、
  Gemini経路は**畳み込み後に `timestamp` 昇順へ並べ直してから**走査する点だけが違う。
  この差はGemini小節側へ書き、既存節は変更しない。
- **トークンが取得できない場合の縮退**（受け入れ条件「空のトークンテーブルや0の羅列にならない」）。
  モデル行が0件ならテーブルをヘッダごと出さず、`- 使用モデル:` 行で使用モデルを残す。
  これは列構成の決め方（次項）とは別の話なので、独立した項として書く。
- トークン列の構成を**データで決める**こと（混在時は和集合）。
- 投稿ガードの拡張（`engine=gemini` のときだけ）。
- ブランチ帰属の限界。
- `_usage_append_push_index` をGemini経路で呼ばないこと。

### 1'. `.claude/rules/directory-structure.md`

`usage/` の内訳は**閉じた列挙**（`usage/session-logs/<sessionId>/`・`usage/state/<branch>.json`・
`usage/state/session-cursors/<sessionId>.json`・`usage/state/push-index.jsonl` の4つ）として書かれて
いる。フェーズ3で新設した **`usage/state/gemini-totals/<sessionId>.json`（Gemini経路の前回累計。
ブランチ非依存）を追記する**。追記しないと列挙が不完全なまま「正」として残り、状態ファイルを
調査する人・機構を他リポジトリへ移植する人がこのパスに気づけない。

**rules配下だがAIアセット反映ではなく本計画で扱う。** 変更の内容が「新設した永続パスの構成を
正しく記す」ことであり、運用ルールの改訂（AIアセット反映の主題）ではないため。

### 1''. `.claude/hooks/lib/UsageTracking.sh` のコメント（**コードのコメントのみ**）

`_usage_sync_session_logs` のコメント（L344〜347）に、spec L839 と**同文の誤った説明**が残っている。

> 「Geminiのログは保存するが対応工数の集計対象にはしない」というissue #23のスコープ境界が、
> 追加のガード条件を書かずに構造だけで保証される。

同じ関数が `cp "$transcript_path" "${log_dir}/main.jsonl"` を行い、その `main.jsonl` を
`_sync_usage_state_gemini` が集計入力にしている以上、**この説明は自分が作った成果物の使われ方を
誤って説明している**。specだけ直すと、本計画が問題視した記述が別の場所に温存される。

- **挙動を変えないコメントのみの修正**として本計画に含める（下記「やらないこと」の例外）。
- サブエージェント分の記述（globが構造的にマッチしない）は**正しいので残す**。書き換えるのは
  「Geminiのログは…集計対象にはしない」という主語が広すぎる部分だけ。

### 2. `.claude/docs/ddr/` へのDDR新規作成（5本）

**採番は flow-id 4-6 の直前に `main` の最新を見て行う**（`main` が進むと衝突するため。
`.claude/skills/resolve-conflict/SKILL.md` 類型A）。以下は内容の割り当てのみを示す。

**仮番号は `DDR-1`〜`DDR-5` とする。** 反映元（`reports/…調査.md`「設計判断」）のIDが
`A`〜`S` のアルファベットなので、DDR側も `A`〜`E` にすると**同じ文字が別物を指して交差する**
（例: 「DDR D」＝ブランチ帰属 と「設計判断D」＝`$rewindTo`）。DDR本文はマージ後に変更できず
取り違えの回復コストが高いため、記号系を分け、**設計判断IDには必ず内容を併記する**。

| 仮番号 | タイトル（案） | まとめる設計判断 |
|---|---|---|
| DDR-1 | Gemini CLIの差分はファイル全体の畳み込みと前回累計の差分で取り前回累計はブランチ非依存に持つ | C（差分の取り方）・S（消失検知）・O（行カーソルを使わない）・レビュー指摘（前回累計をブランチ非依存に持つ）・`_usage_append_push_index` を呼ばない |
| DDR-2 | Gemini CLIの`$rewindTo`は集計から外さない | D（`$rewindTo`の扱い） |
| DDR-3 | 対応工数レポートのトークン列はengineではなくデータで決める | F（トークン列の構成）・レビュー指摘（混在時の和集合） |
| DDR-4 | Gemini経路のブランチ帰属は断面時点のブランチとし限界を明示する | E（ブランチ帰属） |
| DDR-5 | Gemini CLIのサブエージェントは保存のみとし集計しない | I（サブエージェントの扱い） |

- **DDR-1 に C・S・O をまとめる理由**: この3つは「行カーソルが使えない」という1つの事実から
  導かれる一続きの判断であり、別々のDDRにすると相互参照だらけになる。**ブランチ非依存の
  置き場所も、同じ「二重計上を防ぐ」という目的の一部**なので同居させる。

### 2'. 既存DDR 0022 の frontmatter の精査

`.claude/docs/ddr/0022-push断面の全文コピーをやめ行番号インデックスで表現する.md` は
「Gemini CLI対応の扱い」で **「ミラーへの保存は維持し、対応工数の集計対象に含めることは
スコープ外とした。」** と決めている。issue #97 は**この決定のうちメインセッション分を覆した**。

- **`status: superseded` ＋ `superseded_by` を付けるかを判断する。** 0022の主題は
  「push断面を行番号インデックスで表現する」ことであり、Geminiの集計対象外はその一部にすぎない。
  **DDR全体が無効になったわけではないので、`superseded` は過剰かもしれない。**
  付ける／付けないのいずれを選んでも、**判断とその理由を `reports/…設計反映.md` へ残す**
  （`.claude/rules/markdown-frontmatter.md`「DDRのstatus」）。
- **`description` は書き換えない**（同ルール）。**本文も変更しない。**
- **DDR-5 の本文に 0022 への参照を書く。** 0022 のどの部分が生きていて（サブエージェントは
  保存のみ）、どこが置き換わったか（メインセッションは集計対象になった）を明示する。
  これを書かないと、0022 を検索で引き当てた読み手は「Geminiは集計しない」と読んだまま去る。
- 付けた場合は `.claude/docs/README.md` のDDR一覧にも注記を添える（同ルール）。
- **却下案を必ず書く。** 各DDRには、フェーズ2で検討して採らなかった案（行カーソル方式、
  計上済みid集合を持つ案、`$rewindTo` で切り詰める案、`directories` からブランチを推定する案、
  engineで列を切り替える案、サブエージェントを集計する案）を残す。
- **DDR本文は書いたら変更しない。** frontmatterの `status` のみ後から更新可
  （`.claude/rules/markdown-frontmatter.md`）。

### 3. `.claude/docs/README.md`

DDR一覧へ、新規作成した5本を**採番後の番号で**追記する。

## やらないこと

- **AIアセット（`.claude/rules/` `.claude/skills/` `AGENTS.md`）への反映**
  → 別計画（`plans/【AIアセット反映】Gemini集計で得た教訓を反映する.md`）で扱う。
- **既存DDRの本文の変更**（`status` / `superseded_by` の更新を除く）。
- **spec の過去changelog（「影響範囲」の既存エントリ）の書き換え。** 追記のみ行う。
- **issue #105（テレメトリ）・#103・#94 に関する記述の追加。** 本MRの範囲外。
- **コードの**挙動**の変更。** フェーズ3で完了している。
  **例外は `UsageTracking.sh` のコメント修正のみ**（上記「1''」。挙動を変えないため、
  フェーズ3の完了・検証結果と矛盾しない）。

## 検証手順

```bash
# 1. DDR番号の重複が無いこと【採番直後】
#    ローカルの重複（自分が付けた番号どうし）
ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}' | sort | uniq -d   # 何も出なければ重複なし
#    main側との重複。check-base-conflicts.sh は未コミットの新規ファイルを見られないため
#    （git ls-tree でパスを列挙する実装）、この時点では origin/main を直接引く
git fetch origin main
{ ls .claude/docs/ddr/ | grep -oE '^[0-9]{4}';
  git ls-tree -r --name-only origin/main -- .claude/docs/ddr \
    | grep -oE '[0-9]{4}' ; } | sort | uniq -d   # 何も出なければ重複なし

# 2. frontmatterインデックスが再生成できること（新規DDRのfrontmatterが妥当か）
bash .claude/scripts/src/extract-frontmatter.sh .

# 3. 新規DDRがインデックスに載り、type/description/keywords を持つこと
bash .claude/scripts/src/search-frontmatter.sh --type ddr --query gemini

# 4. README.mdのDDR一覧のリンク切れが無いこと
#    リンクは `](ddr/00NN-....md)` 形式（`./` は付かない）。件数も出して「0件マッチ」を検知する
grep -oE '\(ddr/[0-9]{4}[^)]*\)' .claude/docs/README.md | tr -d '()' | tee /dev/stderr \
  | sed 's|^|.claude/docs/|' \
  | while read -r p; do [ -f "$p" ] || echo "リンク切れ: $p"; done
grep -cE '\(ddr/[0-9]{4}' .claude/docs/README.md   # 0 なら検査が空振りしている

# 5. 差し込み位置の前後を目視で確認する（N=差し込んだ行番号。差し込み箇所ごとに実行）
sed -n "$((N - 3)),$((N + 12))p" .claude/docs/spec/issue-mr-workflow.md

# 6. 単体テストへの巻き添えが無いこと
for t in .claude/scripts/test/test_*.sh; do echo "== $t"; bash "$t"; done

# 7. DDR番号の重複が無いこと【コミット直後】
#    ここで初めて check-base-conflicts.sh が新規DDRを見られる（HEADのツリーに載るため）
bash .claude/scripts/src/check-base-conflicts.sh | jq '.hasDuplicateDdrNumber'
```

- **手順1と手順7は別物であり、どちらも省略しない。** `check-base-conflicts.sh` は
  `git ls-tree -r --name-only "$head_ref"` でパスを列挙するため、**未コミットの新規DDRは
  見えない**。コミット前に実行しても `hasDuplicateDdrNumber` は必ず `false` を返し、
  「検証したつもり」になる。採番直後は手順1の突き合わせで、コミット後は手順7で確認する。
- 手順1で重複が出たら、その場で**作業ブランチ側を繰り下げる**
  （`.claude/skills/resolve-conflict/SKILL.md` 類型A。改番対象はファイル名だけではない）。
- **手順4は件数も見る。** パターンが実データに合っていないと `while` ループが1度も回らず、
  リンク切れがあっても何も報告されない（当初 `\(\./ddr/` と書いていて0件マッチだった）。
- **手順5を省略しない。** 「対応工数レポート」節は地の文と箇条書きの入れ子が長く続く構造で、
  L839付近もその中にある。空行が2つ連続する・次の見出しが直前の段落へくっつく、といった崩れは
  差分では目立たない（`.claude/rules/docs-workflow.md`・`.claude/rules/shell-script-style.md`）。
- 手順6では `test_post_issue_create_notice.sh` の `failures=1`（既存の失敗。issue #94）**だけ**が
  出ることを確認する。`UsageTracking.sh` のコメントを直すため、`test_usage_tracking.sh` が
  `passed=81 failures=0` のままであることも確認する。

## 記録先

- 詳細な試行錯誤: `worklog/日付_partitioned-forging-seahorse_【設計反映】Gemini集計の仕様とDDRを反映する_push<N>.md`
- 実施結果（正文）: `reports/日付_partitioned-forging-seahorse_設計反映.md`
