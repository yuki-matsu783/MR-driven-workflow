---
title: 調査結果 — .gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響
type: report
description: .gemini/hooks/ scripts/ docs/ を生成対象から外すかの判断材料として、参照件数・相対リンクの解決可否・除外時の影響を件数付きで測定した結果
tags: [report, gemini, sync-gemini-assets, 調査]
keywords: [参照件数, 相対リンク, 解決先, 死蔵, COPY_EXCLUDED_PREFIXES, 除外, 対照, 空振り, check-doc-references]
---

# 調査結果 — .gemini/ の hooks/ scripts/ docs/ の参照実態と除外時の影響

対応する計画: `wip/plans/【調査】gemini生成対象3ディレクトリの参照実態.md`（issue #172 / PR #193）。

## サマリ（結論の一覧）

**判断そのものはフェーズ3で出す。** ここは材料のみ。

| # | 結論 | 根拠の性質 |
|---|---|---|
| 1 | **`.gemini/hooks/` を指す実行経路は、生成物の中に0件である。** 変換後の hook `command` 6本すべてが `.claude/hooks/` を指す | 実測（生成物の `.gemini/settings.json` を解析）。**Gemini CLI が別経路でそこを読まないことは未観測**（CLI未実行） |
| 2 | **`.gemini/scripts/` を指す呼び出しも、生成物の中に0件である。** `.gemini/` 配下の資産が書いているスクリプトのパス97件すべてが `.claude/scripts/` を指す | 同上（実測＋推論。CLI未実行） |
| 3 | `.gemini/docs/` は**`.gemini/` 内の相対リンクの解決先になっている**。`.gemini/rules/` から17件、`.gemini/skills/` から1件が向かう | 実測（相対リンクを解決して接頭辞判定） |
| 4 | 除外したとき「残るファイルから」切れるリンクは hooks 1件・scripts 1件・docs 18件。hooks/scripts の1件ずつは**どちらも `.gemini/docs/usecase/対応工数を把握する.md` が唯一のリンク元**で、docs/ も外すならリンク元ごと消える | 実測 |
| 5 | `scripts/` を外す場合、`check-doc-references.sh` の除外定義と同 spec の表（2ファイル3行）が**存在しないディレクトリを指す死んだ設定**になる | 実装の確認 |
| 6 | `COPY_EXCLUDED_PREFIXES` の判定は**完全一致**であり、ディレクトリを外すには接頭辞一致への拡張が要る | 実装の確認 |
| 7 | 3ディレクトリで `.gemini/` の**176/215ファイル・2.49MB（78.7%）**を占める。ただし**配布物のサイズは1バイトも減らない**（`.gemini` は `dist-layers.json` で `layer: exclude`） | 実測＋設定の確認 |
| 8 | **18件のリンク元である `.gemini/rules/` 自体にも、読み込まれる設定上の経路が見つからない。** ルールの読み込みは `GEMINI.md`（リポジトリ直下）→ `AGENTS.md` → `.claude/rules/agent-common.md` の import 連鎖で、`.gemini/settings.json` は `general`（`plan.directory` のみ）と `hooks` しか持たない | 実測＋推論（CLI未実行）。**結論1・2と同じ強さの根拠であり、3ディレクトリの性質差を左右する** |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（Linux）／2026-08-23。**git bash（Windows）実機では未計測**。
- 対象リビジョン: ブランチ `claude/gemini-exclude-decision-yp5p70` の **25e1c37**（ベース `origin/main` = **0a9169c**。
  `git merge-base origin/main HEAD` も 0a9169c で、このブランチは main の最新を含む）。
- 走査対象: `.gemini/**/*.md` 142ファイル・相対リンク332件、および `.claude/` 配下の追跡ファイル全体。
- grep の探索範囲は `--exclude-dir=.git --exclude-dir=wip --exclude-dir=usage` を共通に付け、
  件数は `--exclude-dir=.gemini` を足した「元」の側で数えた（理由は下記「測定手順で最初に踏んだ罠」）。
- リンク解決には `os.path.normpath` による正規化（`realpath -m --relative-to=.` 相当）を使った。

## 実施した内容と結果

### 測定手順で最初に踏んだ罠（記録として残す）

**当初の検証手順は空振りしていた。** 敵対的レビュー（フェーズ2・1回目）の指摘で判明し、実際に
再現できた。

| 測り方 | `.gemini/docs/` の件数 | 対照（`.claude/docs/`） | 判定 |
|---|---|---|---|
| リテラル文字列のgrep（**旧手順のコマンドで測った値**） | **2** | **982** | 対照が非0なので**旧の合格条件を満たす** |
| 同じリテラル一致を、**下記「実施条件」の探索条件**で測り直した値 | **2** | **846** | 値は変わるが判定は同じ |
| リンクを解決して接頭辞判定（新手順） | **17**（`.gemini/rules/` 発のみ） | — | 実態と一致 |

**上の2行が使ったコマンドは別物なので、両方を書く。**

```bash
# 旧手順のコマンド（2 / 982 を返す）
grep -rIn --include='*.md' -e '\.gemini/docs/' .claude .gemini | wc -l   # → 2
grep -rIn --include='*.md' -e '\.claude/docs/' .claude .gemini | wc -l   # → 982
# 実施条件の探索条件で測り直したもの（2 / 846 を返す）
EX="--exclude-dir=.git --exclude-dir=wip --exclude-dir=usage --exclude-dir=.gemini"
grep -rIn $EX -e '\.gemini/docs/' . | wc -l    # → 2
grep -rIn $EX -e '\.claude/docs/' . | wc -l    # → 846
```

**「2」の中身は、どちらの測り方かで入れ替わる。**

| 測り方 | 2件の内訳 |
|---|---|
| 旧手順（md限定・`.claude` と `.gemini` の両方） | どちらも `i0000-13-….md:33` の地の文（`.claude/` 側と `.gemini/` 側の**同一行の複製**） |
| 実施条件の探索条件（`.gemini/` 除外・拡張子不問） | 1件は `i0000-13-….md:33` の地の文、**もう1件は `.claude/scripts/test/test_search_frontmatter.sh:73` のアサーション**（Q5で別途扱う生きた参照であり、地の文ではない） |

`.gemini/` 配下のリンクは `.claude/` の逐語コピーゆえ `](../docs/spec/x.md)` の形で書かれ、文字列
`.gemini/docs/` としては現れない。**旧手順のままなら「docs/ を外してもリンクは切れない」という
誤った結論に、合格条件を満たしたまま到達できた。**

もう1つの系統誤差として、`.claude` と `.gemini` を同時に探索すると**同一の記述が2件として計上
される**（`.gemini/` は `.claude/` の逐語コピーであるため）。以下の件数はすべて
`--exclude-dir=.gemini` を付けた「元」の側で数え、`.gemini/` 側の複製は別に併記する。

### Q1: `.gemini/hooks/` を指す参照

```bash
grep -rIn --exclude-dir=.git --exclude-dir=wip --exclude-dir=usage --exclude-dir=.gemini \
  -e '\.gemini/hooks' .
```

| 測定 | 件数 |
|---|---|
| 「元」の側での参照 | **2** |
| うち `.gemini/` 側の複製 | 2（別カウント） |
| 対照: `.claude/hooks` | **246**（非0。探し方は壊れていない） |
| `.gemini/` 配下の資産・settings.json からの実行パス参照（**出現数**） | `.claude/hooks/…` **22件** ／ `.gemini/hooks/…` **0件** |

最後の行は**別の測り方**なので、対象・パターン・単位を明記する。**「0件」はこの対象集合の中での
0件であり、`.gemini/docs/` は含まない**（`.gemini/docs/` からの相対リンク1件は Q3・Q4 で扱う）。

```bash
T=".gemini/rules .gemini/skills .gemini/agents .gemini/settings.json"
grep -rIoh -e '\.claude/hooks/[A-Za-z0-9_/.-]*\.sh' $T | wc -l   # → 22（出現数）
grep -rIoh -e '\.gemini/hooks/[A-Za-z0-9_/.-]*\.sh' $T | wc -l   # → 0（対照は上行の22）
```

2件の内訳はいずれも `.claude/docs/ddr/i0000-13-….md` の地の文で、**`status: superseded`
（`superseded_by: i0070-01`）** の、NTFSジャンクション運用時代の記述である。実行経路でもリンクでもない。

変換後の `.gemini/settings.json` の hook `command`（全6本）:

```
bash $GEMINI_PROJECT_DIR/.claude/hooks/session-start.sh
bash $GEMINI_PROJECT_DIR/.claude/hooks/otel/session-start.sh
bash $GEMINI_PROJECT_DIR/.claude/hooks/block-direct-git-commit.sh
bash $GEMINI_PROJECT_DIR/.claude/hooks/post-push-usage-report.sh
bash $GEMINI_PROJECT_DIR/.claude/hooks/post-push-compact-prompt.sh
bash $GEMINI_PROJECT_DIR/.claude/hooks/post-issue-create-notice.sh
```

**6本すべてが `.claude/hooks/` を指し、`.gemini/hooks/` を指すものは0件。** これは
`.claude/docs/spec/sync-gemini-assets.md` が記す「同期を忘れても両経路が同じスクリプトを実行する」
ための意図的な設計であり、issue #172 本文の見立てと一致する。

### Q2: `.gemini/scripts/` を指す参照

| 測定 | 件数 |
|---|---|
| 「元」の側での参照 | **5** |
| うち `.gemini/` 側の複製 | 5（別カウント） |
| 対照: `.claude/scripts` | **643**（非0） |
| `.gemini/` 配下の資産からのスクリプト呼び出し（**出現数**） | `.claude/scripts/…` **97件** ／ `.gemini/scripts/…` **0件** |

```bash
# 上4行のうち1〜3行目（5 / 5 / 643）
EX="--exclude-dir=.git --exclude-dir=wip --exclude-dir=usage --exclude-dir=.gemini"
grep -rIn $EX -e '\.gemini/scripts' . | wc -l    # → 5
grep -rIn      -e '\.gemini/scripts' .gemini | wc -l   # → 5（.gemini/ 側の複製）
grep -rIn $EX -e '\.claude/scripts' . | wc -l    # → 643（対照。非0）
# 4行目（97 / 0）。Q1 と同じ対象・同じ単位（出現数）で揃えてある
T=".gemini/rules .gemini/skills .gemini/agents .gemini/settings.json"
grep -rIoh -e '\.claude/scripts/[A-Za-z0-9_/.-]*\.sh' $T | wc -l   # → 97（出現数。行数だと96）
grep -rIoh -e '\.gemini/scripts/[A-Za-z0-9_/.-]*\.sh' $T | wc -l   # → 0
```

5件の内訳は次の2種類に分かれる。**この区別が判断に効く。**

| 種類 | 件数 | 場所 |
|---|---|---|
| **生きた設定**（除外すると死ぬ） | 3 | `.claude/scripts/src/check-doc-references.sh:9,14`（`CHECK_DOC_REFERENCES_EXCLUDED_DIRS` に `".gemini/scripts/test/"`）／`.claude/docs/spec/check-doc-references.md:49`（同じ除外を載せた仕様表） |
| superseded DDR の地の文 | 2 | `.claude/docs/ddr/i0000-13-….md:35,63` |

`.gemini/scripts/` を外すと、前者3行は**存在しないディレクトリを指す死んだ設定**になる。

### Q3: `.gemini/docs/` を解決先とする相対リンク

`.gemini/**/*.md` 142ファイルから相対リンク332件を抽出し、各ファイルのディレクトリを基準に
解決して接頭辞で分類した（`realpath -m --relative-to=.` 相当）。現状で解決先が実在するのは330件。

**解決先の分類**

| 解決先 | 件数 |
|---|---|
| `.gemini/docs/` | **300** |
| `.gemini/skills/` | 14 |
| `.gemini/rules/` | 10 |
| リポジトリ直下（`.claude` `DEVELOPERS.md` `HANDOFF.md` `index.md`） | 5 |
| `.gemini/hooks/` | **1** |
| `.gemini/scripts/` | **1** |
| `.gemini/agents/` | 1 |

**リンク元 × 解決先（主なもの）**

| リンク元 | 解決先 | 件数 |
|---|---|---|
| `.gemini/docs/` | `.gemini/docs/` | 282 |
| `.gemini/rules/` | `.gemini/docs/` | **17** |
| `.gemini/docs/` | `.gemini/skills/` | 13 |
| `.gemini/docs/` | `.gemini/rules/` | 5 |
| `.gemini/rules/` | `.gemini/rules/` | 5 |
| `.gemini/skills/` | `.gemini/docs/` | **1** |
| `.gemini/docs/` | `.gemini/hooks/` | 1 |
| `.gemini/docs/` | `.gemini/scripts/` | 1 |

逆方向（`.gemini/docs/` 発のリンク）は305件で、うち282件が `.gemini/docs/` 内で完結し、
23件が `.gemini/` の他のディレクトリ・リポジトリ直下へ向かう。

**リンク元 × 解決先の表は主なもの（8行・325件）で、全332件のうち7件が表に出ていない**
（`rules→.claude` 2 / `rules→index.md` 1 / `rules→skills` 1 / `docs→DEVELOPERS.md` 1 /
`docs→agents` 1 / `docs→HANDOFF.md` 1）。

#### Q3-b: リンク元である `.gemini/rules/` `.gemini/skills/` 自体が読まれる経路はあるか

**Q1・Q2 で hooks/scripts に当てたのと同じ検査を、リンク元の側にも当てる。** 当てないと、
「docs/ を外すと18件切れる」だけが独り歩きし、その18件が**そもそも誰にも読まれないファイルの中の
リンク**かどうかが分からないままになる。

```bash
grep -n '^@' GEMINI.md AGENTS.md
#   GEMINI.md:11:@./AGENTS.md
#   AGENTS.md:11:@./.claude/rules/agent-common.md
ls .gemini/*.md          # → .gemini/REVIEW-POINTS.md のみ（GEMINI.md / AGENTS.md 相当は無い）
jq -r 'keys[]' .gemini/settings.json      # → general, hooks の2つだけ
jq -c '.general' .gemini/settings.json    # → {"plan":{"directory":"./wip/plans"}}
grep -c 'gemini/rules'  .gemini/settings.json   # → 0
grep -c 'gemini/skills' .gemini/settings.json   # → 0
```

**ルールの読み込みは `GEMINI.md`（リポジトリ直下）→ `AGENTS.md` → `.claude/rules/agent-common.md`
という import 連鎖で、`.gemini/rules/` を経由しない。** `.gemini/settings.json` にも
`.gemini/rules/` `.gemini/skills/` を読み込ませるキーは無い（トップレベルは `general` と `hooks`
だけで、`general` は `plan.directory` のみ）。

したがって **`.gemini/rules/` にも、`.gemini/hooks/` `.gemini/scripts/` と同じ根拠が当たる**。
ただし結論1・2と同じく、これは**生成物と設定から導いた推論**であり、Gemini CLI が実行時に
`.gemini/rules/` を読まないことを観測したわけではない（下記「確かめられなかったこと」）。

### Q4: 除外したとき、解決できなくなるリンク

**数えるのは「除外後も残るファイルから、除外されるファイルへ向かうリンク」に限る。** 除外対象の
内部で完結するリンク（`.gemini/docs/` 内の docs→docs）は**リンク元ごと消える**ので切れリンクに
ならない。両者を混ぜると件数が一桁変わる。

| 除外する対象 | 残るファイル基準（**本命**） | 全リンク基準（参考） |
|---|---|---|
| `hooks/` のみ | **1** | 1 |
| `scripts/` のみ | **1** | 1 |
| `docs/` のみ | **18** | 298 |
| `hooks/` + `scripts/` | **2** | 2 |
| 3つすべて | **18** | 300 |

**hooks/ と scripts/ の1件ずつは、どちらも同じファイルが唯一のリンク元である。**

```
.gemini/docs/usecase/対応工数を把握する.md:37: [post-push-usage-report.sh](../../hooks/post-push-usage-report.sh)
.gemini/docs/usecase/対応工数を把握する.md:39: [show-push-log.sh](../../scripts/src/show-push-log.sh)
```

したがって **`docs/` も一緒に外すなら、この2件はリンク元ごと消える**（3つすべてを外した場合の
件数が18件で、docs/ のみの場合と同じなのはこのため）。

**docs/ を外したときに切れる18件の内訳**

| リンク元 | 件数 |
|---|---|
| `.gemini/rules/shell-script-style.md` | 6 |
| `.gemini/rules/markdown-frontmatter.md` | 5 |
| `.gemini/rules/ai-command-style.md` | 2 |
| `.gemini/rules/powershell-encoding.md` | 2 |
| `.gemini/rules/docs-workflow.md` | 1 |
| `.gemini/rules/git-workflow.md` | 1 |
| `.gemini/skills/apply-mr-workflow-to-project/SKILL.md` | 1 |

**なお、現状でも既に2件のリンクが切れている。うち1件は `.claude/` 側の欠陥である**（`.gemini/`
側の傷として書くと、`.gemini/docs/` を外した時点で「消えた」ように見えてしまうが、正である
`.claude/` 側の壊れたリンクは残り続ける）。

| リンク元（**正である `.claude/` 側**） | 内容 |
|---|---|
| `.claude/docs/ddr/i0127-01-….md:132` | `[DDR 0037](0037-リポジトリURLはgh_glabではなくgit-remoteから導出する.md)` を指すが、実在するのは `.claude/docs/ddr/i0044-01-リポジトリURLはgh_glabではなくgit-remoteから導出する.md`（issue #133 の改番前の旧ファイル名が残っている） |
| `.claude/docs/spec/generate-ddr-list.md` | `<link-prefix><ファイル名>` というテンプレート記法の説明が、リンクとして解釈されたもの。**この解析スクリプトの誤検知**であり実害はない |

`.gemini/docs/` 側に見えている同じ2件は、この逐語コピーである。

**`bash .claude/scripts/src/check-doc-references.sh` は「参照切れ数=0」を返す**（絶対パス形式
しか見ないため、この相対リンクを検出できない）。DDR `i0171-01` が置いた「絶対パス形式に限定する」
という限定が、実データで表面化した実例になっている。1件目は本issueのスコープ外なので、
**フェーズ4で別issueへ切り出すか `.claude/docs/` 側へ記録を残すかを決める**（下記「設計への反映」5）。

### Q5: 除外の実装に必要なこと・影響する既存テスト

**`COPY_EXCLUDED_PREFIXES` の現在の意味論は「完全一致」であり、そのままではディレクトリ配下を
落とせない。**

```bash
# .claude/scripts/src/sync-gemini-assets.sh の is_copy_excluded
for p in "${COPY_EXCLUDED_PREFIXES[@]}"; do
  [ "$rel" = "$p" ] && return 0     # ← 完全一致
done
```

変数名は `PREFIXES` だが判定は完全一致で、現在の唯一の要素も `.claude/settings.json` という
1ファイルである。ディレクトリを外すには**接頭辞一致（または `case` によるパターン一致）への拡張**が要る。

| 対象 | 影響 |
|---|---|
| `.claude/scripts/test/test_sync_gemini_assets.sh` | **要変更**。T8（除外対象が出力に含まれないこと）に「除外したディレクトリが出力に無いこと」「除外していないディレクトリは残ること」の対を追加する。T6（冪等性）・T7（`--check`）・T17（0件判定）は仕組みに触れないため素通りする見込み |
| `.claude/scripts/test/test_search_frontmatter.sh:73` | **影響なし**。`sf_is_excluded_path` は文字列を受け取る純粋関数で、ファイルシステムを触らない。しかも判定はパス**セグメント**一致（`case "/$path/" in *"/$dir/"*`）で `.gemini` 自体に当たるため、サブディレクトリの有無に依存しない |
| `.claude/scripts/src/check-doc-references.sh` / 同 spec | **要追随**（`scripts/` を**外す場合のみ**）。上記 Q2 の3行 |
| `.claude/rules/directory-structure.md:50` | **要追随**（**外す対象に依らず**）。`docs/ hooks/ rules/ scripts/ skills/` を「そのままコピー」と説明するツリー行が、どれか1つを外した時点で誤りになる |
| `.claude/docs/spec/sync-gemini-assets.md:96-97` | **要追随**（**外す対象に依らず**）。「`.claude/agents/*.md` と `.claude/settings.json` はコピー対象から外し…それ以外のファイルは**内容を変えずにコピーする**」という、コピー対象の定義そのものが変わる |
| `.claude/scripts/src/check-dist-coverage.sh` | **影響なし**。理由は「本文に `.gemini` の言及が0件」ではない（このスクリプトは `dist-layers.json` の `.gemini` エントリ経由で `.gemini` を扱うため、本文の言及数は影響の有無を示さない）。**`.gemini` エントリがサブツリー全体を被覆しており、配下が減っても残りのファイルに当たり続けるので検査3の空振り判定に入らない。** 実行して4種すべて通過することを確認済み（検査1 457/457・検査2 10/10・検査3 空振り0件・検査4 不正0件） |
| `.claude/dist-layers.json` | **影響なし**。`.gemini` は `layer: exclude` のまま |

### Q6: 除外で減る量（実測）

| 対象 | ファイル数 | バイト数 |
|---|---|---|
| `.gemini/hooks/` | 14 | 217,308 |
| `.gemini/scripts/` | 47 | 813,984 |
| `.gemini/docs/` | 115 | 1,456,431 |
| **3ディレクトリ合計** | **176** | **2,487,723** |
| `.gemini/` 全体 | 215 | 3,159,948 |
| **割合** | **81.9%** | **78.7%** |

`--check` の所要時間は3回の実行で 116ms / 95ms / 91ms（いずれも終了コード0）。
**変更前の `bash .claude/scripts/test/test_sync_gemini_assets.sh` は `passed=91 failures=0`**
（フェーズ3で除外を実装したあと、この数字と比べる）。

**「配布物のサイズ」は1バイトも減らない。** `.claude/dist-layers.json` は `.gemini` を
`layer: exclude` と定義しており、`.gemini/` はそもそも配られない（配布先で
`install-to-project.sh` が `sync-gemini-assets.sh` を実行して生成する）。減るのは
**このリポジトリと配布先で生成される `.gemini/` のサイズ**であって、配布物のサイズとは別物である。

### 再現手順

測定に使ったリンク解析スクリプトは `wip/worklogs/` の同名 push のログに全文を残した。
**Q1〜Q3・罠の表の各件数には、実際に実行したコマンドを本文中に併記してある**（対象・パターン・
単位まで書き、行数と出現数を混ぜない）。

**「0件」と書いた測定のうち、対照を付けてあるのは次のものである。**

| 0件の主張 | 対照 |
|---|---|
| `.gemini/hooks/…` への実行パス参照 0件 | 同じ対象・同じパターンの `.claude/hooks/…` が22件 |
| `.gemini/scripts/…` への呼び出し 0件 | 同じ対象・同じパターンの `.claude/scripts/…` が97件 |
| `.gemini/settings.json` に rules/skills を読み込ませるキー 0件 | **対照なし**。`grep -c` が0であることしか示していない（同じ形で非0を返す既知のキーが無いため） |
| `check-dist-coverage.sh` 本文の `.gemini` 言及 0件 | **対照なし**。かつ上記 Q5 のとおり、この0件は影響の有無を示さないので根拠から外した |

対照を付けられなかった2件は、いずれも**それ単独では結論を支えていない**（前者は import 連鎖の
実測と併せて読む、後者は `dist-layers.json` の被覆で置き換えた）。

## 確かめられなかったこと

- **Gemini CLI 実機での挙動は確かめていない。** この実行環境に Gemini CLI が無い
  （`command -v gemini` が空）。したがって「`.gemini/hooks/` `.gemini/scripts/` は読まれない」は
  **生成物の中身（hook `command` の値・資産が書いているパス）から導いた結論**であり、
  Gemini CLI が実行時に別経路でそれらを読みに行かないことまでは観測していない。これは
  `.claude/docs/spec/sync-gemini-assets.md`「未決定事項・懸念点」が既に持つ制約と同じものである。
- **`.gemini/docs/` を Gemini CLI が読むか**も同様に未確認である。上記 Q3 が示したのは
  「`.gemini/` 側だけを見る読み手が辿るリンクの解決先になっている」ことであって、
  Gemini CLI 自身がリンクを辿るかどうかではない。
- **測定は Linux 1環境・1リビジョンのもの**である。`--check` の所要時間（91〜116ms）は、
  外部プロセス起動が桁で遅い git bash 実機ではそのまま当てはまらない
  （`.claude/rules/shell-script-style.md`「外部プロセス起動のコスト」）。
- **除外を実装した状態でのテスト結果は測っていない。** Q5 は既存の実装・テストを読んで
  「どこに手が要るか」を出したもので、実際に通したのは**変更前**の
  `test_sync_gemini_assets.sh` の `passed=91 failures=0` である。
- **`.gemini/rules/` `.gemini/skills/` が読まれないことも、同じく未観測である**（Q3-b）。
  示したのは「設定と import 連鎖の中にそれらを読み込ませる経路が無い」ことまでで、
  Gemini CLI が `.gemini/` 配下を暗黙に走査しないことは確かめていない。**この1点は
  3ディレクトリの採否を左右するため、フェーズ3で「未観測のまま判断する」と明記する必要がある。**

## 設計への反映

フェーズ3（flow-id 3-1〜）で次を決める。

1. **3ディレクトリそれぞれの採否。** hooks/ と scripts/ は「指す経路が生成物中に0件・切れるリンクは
   1件・追随箇所は scripts/ のみ2ファイル3行」。docs/ は「`.gemini/` 内の相対リンクの解決先・
   切れるリンク18件」。**ただし Q3-b により、その18件のリンク元である `.gemini/rules/` 自体にも
   読み込まれる経路が見つかっていない。** 「切れるリンク18件」を、読まれるファイルの中の18件と
   読むか、読まれないファイルの中の18件と読むかで結論が変わる——**ここがフェーズ3の争点である**。
2. **hooks/ と scripts/ の切れリンク1件ずつの扱い。** 唯一のリンク元
   （`.gemini/docs/usecase/対応工数を把握する.md`）は `.claude/` 側の逐語コピーであり、
   `.claude/` 側では正しく解決される。`.gemini/docs/` の扱いと連動して決める。
3. **除外の実装形。** `is_copy_excluded` を接頭辞一致（または `case` パターン）へ拡張し、
   T8 へ「除外したディレクトリが出力に無いこと」「除外していないディレクトリは残ること」の対を
   追加する。
4. **ドキュメントの追随。** `scripts/` を外す場合は `check-doc-references.sh` と同 spec。
   **どれを外す場合でも** `.claude/rules/directory-structure.md:50` と
   `.claude/docs/spec/sync-gemini-assets.md:96-97`。
5. **`.claude/docs/ddr/i0127-01-….md:132` の切れリンクの扱い**（本issueのスコープ外の既存の欠陥）。
   別issueへ切り出すか、`.claude/docs/` 側へ記録を残すかを決める。

## 想定と異なった点

| 計画時の見込み | 実際 |
|---|---|
| 3ディレクトリへの参照は「0件か非0件か」で単純に分かれる | `.gemini/scripts/` への5件は**性質が2種類**に分かれた（生きた除外設定3行 ＋ superseded DDR の地の文2行）。件数だけでは判断できない |
| docs/ を外すと切れるリンクは数百件 | **18件**。全リンク基準の298件のうち282件は `.gemini/docs/` 内で完結しており、リンク元ごと消える |
| hooks/ scripts/ への参照は完全に0件 | 相対リンクとして**1件ずつ**存在した（同じ1ファイルから） |
| 除外すれば配布物が小さくなる | **1バイトも変わらない**。`.gemini` は `dist-layers.json` で `layer: exclude` |
| docs/ だけが「読まれる」側で、hooks/ scripts/ と性質が分かれる | **リンク元の `.gemini/rules/` にも読み込まれる経路が見つからなかった**（Q3-b）。性質差は当初の見立てほど明確ではない |

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172 / PR #193。
