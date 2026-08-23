---
title: 【設計反映】配布方式のspecとDDRへの反映
type: plan
description: manifest方式への作り直しを spec（distribution-assets.md の更新と新方式の spec 新設）と DDR（方式選定ほか）へ反映する
tags: [plan, 設計反映, distribution, ddr, spec]
keywords: [distribution-assets, dist-layers, asset-manifest, DDR, i0026-01, 方式選定, 未決定事項, changelog, point-in-time, generate-ddr-list]
---

# 【設計反映】配布方式のspecとDDRへの反映

flow-id 4-6（設計反映）。`plans/` `worklog/` `reports/` の内容を `.claude/docs/spec/` と
`.claude/docs/ddr/` へ反映する。**実装コード・テストコードは変更しない**
（変更を伴うものは `【実装反映】` 側が扱う）。

## この計画の範囲

| 対象 | やること |
|---|---|
| `.claude/docs/spec/distribution-assets.md` | 陳腐化した節の書き換え／未決定事項の整理／changelogへの新規エントリ追記 |
| `.claude/docs/spec/asset-distribution.md`（**新規**） | manifest方式そのものの正史 |
| `.claude/docs/ddr/i0026-01-….md`（**新規1件**） | 方式選定（受け入れ条件11）ほか3つの決定を節に分けて書く |
| `.claude/docs/README.md` | `generate-ddr-list.sh` の再実行（生成物） |

**範囲外**: `.claude/rules/` `.claude/skills/` の更新（`【AIアセット反映】` が扱う）、
`.claude/VERSION`（同上）、実装・テストの修正（`【実装反映】` が扱う）。

## 1. `distribution-assets.md` の更新

**このファイルは「配布**アセット**（PR/MRテンプレート・`.gitattributes`・`.claude/VERSION`）の
仕様」であり、配布**機構**の仕様ではない。** 機構は下記2で新設する側が持つ。両者の役割を
混ぜないこと。

### 1-a. 書き換える箇所

| 行 | 現状 | 書き換え |
|---|---|---|
| 6（frontmatter `keywords`） | `sync-assets` を含む | `dist-layers` / `asset-manifest` へ差し替え |
| 94〜123（`### 配布経路での扱い`） | `sync-assets.sh` と `install-to-project.sh` の2列表。`safe_copy_dir` / `ALWAYS_OVERWRITE_RELPATHS` / `ensure_gitattributes_rules` を現在の仕様として記述 | **3資産それぞれの「層」と、その層で何が起きるか**へ全面書き換え |

新しい対応表（実装で確定した値。**実ファイルで確認してから書く**）:

| 資産 | 層 | 配布先の既存ファイルの扱い |
|---|---|---|
| PR/MRテンプレート（`.github/` `.gitlab/`） | **`core`** | 常に上書き（差分があれば `.bak` 退避） |
| `.claude/VERSION` | **`core`**（`.claude` エントリに含まれる） | 同上 |
| `.gitattributes` | **`merge`（`lines-marker`）** | 上書きしない。マーカー間の行が無ければ足すだけ |

- **未決定事項の表（161〜166行目付近）が「PR/MRテンプレート = `seed`」と書いているのは誤り**
  である（実装は `core`）。この行は #26 側で決めると断ったうえでの見込みなので、
  **書き換えるのではなく、決着したものとして未決定事項から外す**（下記1-b）。
- `.gitattributes` の**マーカーの説明（42〜66行目）は現在も正しい**。読む主体が
  `ensure_gitattributes_rules` から `merge` 層の `lines-marker` 戦略へ変わっただけなので、
  **「読む主体」を書き換え、マーカーの規約自体は残す**。

### 1-b. 未決定事項の整理

`## 未決定事項・懸念点`（151行目〜）の5項目のうち、**4項目は #26 で決着した**。
`.claude/rules/docs-workflow.md` は「`spec` の未決定事項が解消したら記録し、spec側の該当項目は
削除してよい」と定めているので、**解消したものは削除し、どこで解消したかを changelog へ書く**。

| 項目 | 扱い |
|---|---|
| Windows実機（git bash）での改行挙動が未確認 | **残す**（未解消。新方式にも同種の未確認が増えるので、下記2の新specへ集約するか、ここに残すかを実装時に決める） |
| issue #26 への移行時にどこが引き継がれるか（層の対応表） | **削除**（決着。上記1-aの表が正になる） |
| `.gitignore` 追記処理の3つの問題（非冪等・部分一致・行の不一致） | **削除**（`merge` / `lines-marker` で作り直して解消。実測で確認済み） |
| `HAS_WARNED` が `safe_copy_dir` の外へ伝わらない | **削除**（`safe_copy_dir` ごと廃止） |
| 配布先へ `.gitignore` 対象のローカル生成物が混入する | **削除**（`local` 層で解消） |

**「削除してよい」は「黙って消してよい」ではない。** 削除した4項目それぞれについて、
**どのissueのどの仕組みで解消したか**を changelog の新規エントリへ1行ずつ残す。

### 1-c. changelog（`## 影響範囲`）

- **既存のエントリ（`### issue #33（初版）` `### issue #54（2026-08-22）`）は1文字も変更しない。**
  point-in-time の記録であり、当時の実装を指す `sync-assets.sh` `safe_copy_dir` という語も
  当時の事実として正しい（`.claude/rules/docs-workflow.md`「ファイル移動に伴うパス参照の一括置換は
  …過去changelogを対象に含めない」）。
- **`### issue #26（2026-08-23）` を新規エントリとして追記する。** 内容は、3資産の層の確定・
  未決定事項4件の解消・`sync-assets.sh` の廃止・**`.claude/VERSION` を `0.2.0` のまま据え置いた事実と
  その理由**（flow-id 4-4 のレビューで確定済み。`distribution-assets.md`「人間の判断で据え置くことが
  ある」節が、据え置いた場合はそのissueのchangelogへ残すと定めているため**必須**）。

> **一括置換を絶対にかけないこと。** このファイルは「直す行（6・94〜123）」と「触ってはいけない
> 行（125〜150）」が同居している。`sed` で `sync-assets` を全置換すると過去の記録が壊れる
> （フェーズ2の調査結果でも同じ注意を出している）。

## 2. 新方式のspecを新設する

`.claude/docs/spec/asset-distribution.md`（ファイル名は実装時に確定してよい）。
**配布機構そのもの**の正史で、`distribution-assets.md`（配る資産の側）とは別ファイルにする。

含める内容:

| 節 | 内容 |
|---|---|
| 背景・目的 | 収穫（逆輸入）の前提として、適用した版と層を機械可読に持つ |
| 5つの層 | `core` / `seed` / `merge` / `local` / `exclude` の定義と、**`exclude` を明示必須にした理由** |
| 層分け定義 `.claude/dist-layers.json` | スキーマ・**後に書いたエントリが勝つ**規約・`source` / `strategy` / `keys` / `header` / `gitignorePattern` / `requiredLine` / `upstream` |
| manifest `.claude/.asset-manifest.json` | スキーマ・`source.commit`・LF正規化した sha256・`-dirty` の付与条件 |
| インストーラの2パス構成 | 走査 → 提示 → 配置。**受け入れ条件4は1パスでは満たせない**という制約 |
| `merge` の2戦略 | `lines-marker` / `json-keys`。それぞれの冪等性と検証 |
| `requiredLine` | 旧形式のまま残った `seed` を**触らずに一覧で知らせる** |
| 網羅性チェック | 検査4種。分母は追跡ファイル全件。配布先では `upstream` の印が無いのでスキップ |
| 削除・改名の扱い | **配布元で消えたファイルは配布先に残る**（一覧の提示のみ） |
| 未決定事項・懸念点 | 下記 |

**未決定事項として残すもの**（いずれも**Windows実機でしか確認できない**）:

1. `.gemini/` のリンクと実体コピーの判別（NTFSジャンクションは `[ -L ]` で区別できない）
2. sha256のLF正規化が Windows 実機で意図どおり効くか
3. `AGENTS.md` からの `@` import が `.claude/rules/agent-common.md` へ解決するか
4. 上記1-bの「Windows実機での改行挙動」をこちらへ集約するかどうか（実装時に決める）

## 3. DDRを追加する

**識別子は `i0026-01` の1件のみ**（`.claude/rules/markdown-frontmatter.md`「DDRの識別子」）。
`.claude/docs/ddr/` に `i0026-` が無いことは確認済み。

**当初は3件（方式選定／`exclude` を明示必須にした判断／`AGENTS.md` を `core` にしなかった判断）へ
分ける案だったが、flow-id 4-4 のレビューで「細かいので1つにする」という判断を受けた。**
分けない代わりに、1件のDDRの中で**節を分けて**3つの決定を書く。

| 節 | 決定 | 却下案 |
|---|---|---|
| 3-a | **配布方式としてmanifest付きの直接コピーを選ぶ**（受け入れ条件11） | git subtree／Claude Code plugin配布／差分をAIが都度判断する案 |
| 3-b | **層は4つではなく `exclude` を加えた5つにし、配らないことを明示指定にする** | 暗黙の既定値（未指定＝配らない）とする案。**網羅性チェックが常に通ってしまう**ため却下 |
| 3-c | **旧形式のまま残った `seed` は、`core` へ昇格させず `requiredLine` で一覧提示にとどめる** | `AGENTS.md` を `core` にする案。**プロジェクト概要という配布先の所有物が消える**ため却下 |

- **タイトルは3つを束ねた1文にする**（例: 「AIアセットの配布はmanifest付きの直接コピーとし、
  層は `exclude` を含む5つにする」）。**3-c まで題名へ詰め込まない**（長くなりすぎるため、
  本文の節見出しで示す）。
- **束ねたことの帰結を承知しておく。** 後から一部だけが無効になっても、
  `status: superseded` はDDR単位でしか付けられない。その場合は**後続のDDRの本文で
  「i0026-01 の 3-b のみを置き換える」と明示する**（frontmatterでは表せないため）。
  この制約自体をDDR本文の末尾へ1行残す。
- **DDRを追加したら必ず `bash .claude/scripts/src/generate-ddr-list.sh` を実行し、
  `.claude/docs/README.md` の差分を同じコミットへ含める**（一覧は生成物。手書きしない。issue #135）。

## 触ってはいけない箇所

| 対象 | 理由 |
|---|---|
| `.claude/docs/ddr/**` の**既存の本文** | 一度マージしたDDRの本文は変更しない。**`i0033-03` が `ensure_gitattributes_rules` を書いているのはそのまま残す**（当時の事実） |
| `distribution-assets.md` の125〜150行目（既存changelog） | point-in-time の記録（上記1-c） |
| `issue-mr-workflow.md` の 2369 / 3071 / 3080 行目付近 | いずれも**過去issueのchangelogの中**（issue #63 / #54）。`sync-assets.sh` `safe_copy_dir` という語が出るが、当時の記録なので直さない |
| `.claude/rules/directory-structure.md` 142〜144行目 | フェーズ3で既に現状へ更新済み。再度触らない |

## 検証（この計画の完了判定に実際に流すコマンド）

```bash
# 1. 削除済みの語が「現在の仕様」として残っていないこと（changelog の行は除く）
git -c core.quotepath=false grep -n -e 'sync-assets' -e 'safe_copy_dir' \
  -e 'ALWAYS_OVERWRITE_RELPATHS' -e 'ensure_gitattributes_rules' \
  -- '.claude/docs/spec' '.claude/rules' 'index.md' 'DEVELOPERS.md'

# 2. DDR一覧が最新であること
bash .claude/scripts/src/generate-ddr-list.sh --check

# 3. DDR識別子の重複が無いこと
ls .claude/docs/ddr/ | grep -oE '^(i[0-9]+-[0-9]{2}|[0-9]{4})' | sort | uniq -d

# 4. frontmatterインデックスに新しいspec・DDRが載ること
bash .claude/scripts/src/extract-frontmatter.sh .
bash .claude/scripts/src/search-frontmatter.sh --type spec --type ddr | grep -c -- 'i0026-01\|asset-distribution'

# 5. 網羅性チェック（新規specとDDRが core に載る。分母が増える）
bash .claude/scripts/src/check-dist-coverage.sh

# 6. 単体テスト（specの変更で落ちるものは無いはずだが、DDR一覧の自己検証があるため必ず流す）
for t in .claude/scripts/test/test_*.sh; do bash "$t" | tail -1; done
```

**検証1は「0件になること」を期待しない。** changelog の行が必ず残るため、**残った行がすべて
changelog の中であること**を目視で確認する（件数と行番号を結果レポートへ書く）。

## この計画の中で互いの前提を崩していないか（自己点検）

- **1-b で「未決定事項から削除する」ものと、1-c で「changelogへ書く」ものは同じ4項目**である。
  片方だけ実施すると、解消の記録がどこにも残らない（削除だけ）か、二重に残る（追記だけ）。
  **必ず対にして行う。**
- **1-a の対応表は「実装で確定した値」であって、この計画で決める値ではない。**
  `.claude/dist-layers.json` を読んで書き写すこと。計画に書いた表と実装が食い違っていたら
  **実装が正**であり、計画側の誤りとして結果レポートへ残す。
- **2 の新specと 1 の `distribution-assets.md` は、同じことを二重に書かない。**
  `.gitattributes` のマーカー規約は `distribution-assets.md` 側が持ち、`merge` / `lines-marker`
  という**戦略の仕様**は新spec側が持つ。互いに参照リンクで繋ぐ。
- **3 の節3-a（方式選定）は受け入れ条件11そのもの**である。これを書かずにフェーズ4を終えると、
  **受け入れ条件が1つ未達のままマージへ進む**ことになる。3件を1件へ束ねたことで、
  **3-a が3-b・3-c に埋もれて薄くなる危険が出た**。却下案（git subtree / plugin配布 /
  差分をAIが都度判断する案）はこの節にだけ書き、分量も3節のうち最も厚くする。
