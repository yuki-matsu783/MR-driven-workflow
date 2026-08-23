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
| 1 | `.gemini/hooks/` は Gemini CLI から**読まれない**。変換後の hook `command` 6本すべてが `.claude/hooks/` を指し、`.gemini/hooks/` を指すものは0件 | 実測（生成物の `.gemini/settings.json` を解析） |
| 2 | `.gemini/scripts/` も**読まれない**。`.gemini/` 配下の資産からのスクリプト呼び出し97件すべてが `.claude/scripts/` を指し、`.gemini/scripts/` は0件 | 実測（grep・対照付き） |
| 3 | `.gemini/docs/` は**リンクの解決先として読まれうる**。`.gemini/rules/` から17件、`.gemini/skills/` から1件が向かう | 実測（相対リンクを解決して接頭辞判定） |
| 4 | 除外したとき「残るファイルから」切れるリンクは hooks 1件・scripts 1件・docs 18件。hooks/scripts の1件ずつは**どちらも `.gemini/docs/usecase/対応工数を把握する.md` が唯一のリンク元**で、docs/ も外すならリンク元ごと消える | 実測 |
| 5 | `scripts/` を外す場合、`check-doc-references.sh` の除外定義と同 spec の表（2ファイル3行）が**存在しないディレクトリを指す死んだ設定**になる | 実装の確認 |
| 6 | `COPY_EXCLUDED_PREFIXES` の判定は**完全一致**であり、ディレクトリを外すには接頭辞一致への拡張が要る | 実装の確認 |
| 7 | 3ディレクトリで `.gemini/` の**176/215ファイル・2.49MB（78.7%）**を占める。ただし**配布物のサイズは1バイトも減らない**（`.gemini` は `dist-layers.json` で `layer: exclude`） | 実測＋設定の確認 |

## 実施条件（測った対象・環境）

- 実行環境: Claude Code on the web（Linux）／2026-08-23。**git bash（Windows）実機では未計測**。
- 対象リビジョン: `claude/gemini-exclude-decision-yp5p70`（`origin/main` の 25e1c37 時点）。
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
| リテラル文字列のgrep（旧手順） | **2**（しかも実体はDDRの地の文でリンクではない） | 982 | 対照が非0なので**旧の合格条件を満たす** |
| リンクを解決して接頭辞判定（新手順） | **17**（`.gemini/rules/` 発のみ） | — | 実態と一致 |

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
| `.gemini/` 配下の資産・settings.json からの実行パス参照 | `.claude/hooks/…` **22件** ／ `.gemini/hooks/…` **0件** |

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
| `.gemini/` 配下の資産からのスクリプト呼び出し | `.claude/scripts/…` **97件** ／ `.gemini/scripts/…` **0件** |

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

**なお、現状でも既に2件のリンクが切れている**（除外とは無関係の既存の傷）。

- `.gemini/docs/ddr/i0127-01-….md` → `0037-リポジトリURLは…md`（issue #133 の改番前の旧ファイル名）
- `.gemini/docs/spec/generate-ddr-list.md` → `<link-prefix><ファイル名>`（テンプレート記法の説明が
  リンクとして解釈されたもの。**誤検知**であり実害はない）

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
| `.claude/scripts/src/check-doc-references.sh` / 同 spec | **要追随**（`scripts/` を外す場合）。上記 Q2 の3行 |
| `.claude/scripts/src/check-dist-coverage.sh` | **影響なし**（`.gemini` への言及が0件） |
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
現状の単体テストは `passed=91 failures=0`。

**「配布物のサイズ」は1バイトも減らない。** `.claude/dist-layers.json` は `.gemini` を
`layer: exclude` と定義しており、`.gemini/` はそもそも配られない（配布先で
`install-to-project.sh` が `sync-gemini-assets.sh` を実行して生成する）。減るのは
**このリポジトリと配布先で生成される `.gemini/` のサイズ**であって、配布物のサイズとは別物である。

### 再現手順

測定に使ったリンク解析スクリプトは `wip/worklogs/` の同名 push のログに全文を残した。
grep 系はすべて本文中にコマンドを併記している。**0件と書いた測定にはすべて対照を付けてあり、
対照が非0であることを確認済み**である。

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
  「どこに手が要るか」を出したもので、実際に通したのは**変更前**の `passed=91 failures=0` である。

## 設計への反映

フェーズ3（flow-id 3-1〜）で次を決める。

1. **3ディレクトリそれぞれの採否。** 材料は上記のとおりで、hooks/ と scripts/ は「読まれない・
   切れるリンクは1件・追随箇所は scripts/ のみ2ファイル3行」、docs/ は「読まれうる・切れるリンク
   18件」と、**性質がはっきり分かれている**。
2. **hooks/ と scripts/ の切れリンク1件ずつの扱い。** 唯一のリンク元
   （`.gemini/docs/usecase/対応工数を把握する.md`）は `.claude/` 側の逐語コピーであり、
   `.claude/` 側では正しく解決される。`.gemini/docs/` の扱いと連動して決める。
3. **除外の実装形。** `is_copy_excluded` を接頭辞一致（または `case` パターン）へ拡張し、
   T8 へ「除外したディレクトリが出力に無いこと」「除外していないディレクトリは残ること」の対を
   追加する。
4. **`check-doc-references.sh` と同 spec の追随**（`scripts/` を外す場合）。

## 想定と異なった点

| 計画時の見込み | 実際 |
|---|---|
| 3ディレクトリへの参照は「0件か非0件か」で単純に分かれる | `.gemini/scripts/` への5件は**性質が2種類**に分かれた（生きた除外設定3行 ＋ superseded DDR の地の文2行）。件数だけでは判断できない |
| docs/ を外すと切れるリンクは数百件 | **18件**。全リンク基準の298件のうち282件は `.gemini/docs/` 内で完結しており、リンク元ごと消える |
| hooks/ scripts/ への参照は完全に0件 | 相対リンクとして**1件ずつ**存在した（同じ1ファイルから） |
| 除外すれば配布物が小さくなる | **1バイトも変わらない**。`.gemini` は `dist-layers.json` で `layer: exclude` |

---

正文はこの md 側。人間レビュー用のビューは同名の `.html`。issue #172 / PR #193。
